using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Core.Helpers;
using CourtSide.Core.StateMachines;
using CourtSide.Infrastructure;
using CourtSide.Services.Services;
using CourtSide.Shared.Models;
using CourtSide.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Stripe;
using PaymentMethod = CourtSide.Core.Enumerations.PaymentMethod;

namespace CourtSide.Services.Payments;

public interface IPaymentService
{
    Task<PaymentDto> GetByReservationAsync(int reservationId);

    /// <summary>Creates (or reuses) a Stripe PaymentIntent for the reservation's online payment.</summary>
    Task<PaymentIntentDto> CreateIntentAsync(int reservationId);

    /// <summary>Admin: records that cash was collected on-site.</summary>
    Task<PaymentDto> MarkCashPaidAsync(int reservationId);

    /// <summary>Starts a refund of a collected payment. Online refunds settle against Stripe; manual
    /// refunds (cash, or a card payment with no processor reference) stay pending until an
    /// administrator confirms the money was handed back. A refund the processor cannot take is
    /// recorded as failed, with the reason, and returned rather than thrown. No-op if nothing was
    /// collected.</summary>
    Task<PaymentDto?> RefundAsync(int reservationId);

    /// <summary>Admin: confirms that a manual refund (cash, or a card payment with no processor
    /// reference) was physically paid out.</summary>
    Task<PaymentDto> ConfirmCashRefundAsync(int reservationId);

    /// <summary>Settles online refunds still pending at the processor. Returns how many closed.</summary>
    Task<int> ReconcilePendingRefundsAsync(CancellationToken cancellationToken = default);

    /// <summary>Completes card payments that Stripe has collected but the server has not yet heard
    /// about (the client's check and the webhook both missed). Returns how many were completed.</summary>
    Task<int> ReconcilePendingPaymentsAsync(CancellationToken cancellationToken = default);

    /// <summary>Server-side check of the Stripe PaymentIntent status; finalizes the payment if it succeeded.
    /// The client calls this right after the payment sheet closes, so payments work without the webhook.</summary>
    Task<PaymentDto> VerifyAsync(int reservationId);

    /// <summary>Handles a verified Stripe webhook (payment_intent.succeeded / payment_failed).</summary>
    Task HandleWebhookAsync(string json, string signature);
}

/// <summary>
/// Payment workflow for reservations: Stripe (sandbox) online payments via PaymentIntent + webhook,
/// plus on-site cash and refunds.
/// </summary>
public class PaymentService : IPaymentService
{
    private readonly DatabaseContext _db;
    private readonly StripeSettings _stripe;
    private readonly ICurrentUser _currentUser;
    private readonly INotificationService _notifications;
    private readonly IAppClock _clock;
    private readonly ILogger<PaymentService> _logger;

    public PaymentService(DatabaseContext db, IOptions<StripeSettings> stripe, ICurrentUser currentUser,
        INotificationService notifications, IAppClock clock, ILogger<PaymentService> logger)
    {
        _db = db;
        _stripe = stripe.Value;
        _currentUser = currentUser;
        _notifications = notifications;
        _clock = clock;
        _logger = logger;
    }

    public async Task<PaymentDto> GetByReservationAsync(int reservationId)
    {
        var payment = await LoadAsync(reservationId);
        EnsureOwnerOrAdmin(payment.Reservation);
        return ToDto(payment);
    }

    public async Task<PaymentIntentDto> CreateIntentAsync(int reservationId)
    {
        var payment = await LoadAsync(reservationId);
        EnsureOwnerOrAdmin(payment.Reservation);
        EnsureStripeConfigured();
        EnsurePolicy(payment, PaymentAction.StartOnlinePayment);

        var requestOptions = new RequestOptions { ApiKey = _stripe.SecretKey };
        var service = new PaymentIntentService();
        var amountMinor = (long)Math.Round(payment.Amount * 100m, MidpointRounding.AwayFromZero);

        try
        {
            var intent = await GetOrCreateIntentAsync(payment, amountMinor, service, requestOptions);
            if (intent is null)
            {
                // The intent had already succeeded, so it was finalized instead of reused.
                throw new BusinessException("Rezervacija je već plaćena.");
            }

            if (PaymentPolicy.CanChangeMethod(payment.Status))
                payment.Method = PaymentMethod.Stripe;
            payment.StripePaymentIntentId = intent.Id;
            payment.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return new PaymentIntentDto
            {
                ClientSecret = intent.ClientSecret,
                PublishableKey = _stripe.PublishableKey,
                Amount = amountMinor,
                Currency = payment.Currency
            };
        }
        catch (StripeException ex)
        {
            _logger.LogWarning(ex, "Stripe: kreiranje PaymentIntent-a nije uspjelo za rezervaciju {Id}.", reservationId);
            throw new BusinessException($"Stripe greška: {ex.StripeError?.Message ?? ex.Message}");
        }
    }

    /// <summary>
    /// Stripe intents cannot be revived once cancelled, so a stale id must be replaced rather than
    /// handed back to the client. Returns null when the intent already succeeded, in which case the
    /// payment is finalized here instead (the webhook was evidently missed).
    /// </summary>
    private async Task<PaymentIntent?> GetOrCreateIntentAsync(Payment payment, long amountMinor,
        PaymentIntentService service, RequestOptions requestOptions)
    {
        if (!string.IsNullOrEmpty(payment.StripePaymentIntentId))
        {
            PaymentIntent? existing = null;
            try
            {
                existing = await service.GetAsync(payment.StripePaymentIntentId, requestOptions: requestOptions);
            }
            catch (StripeException ex) when (ex.StripeError?.Code == "resource_missing")
            {
                // The id belongs to another Stripe account (keys rotated) — treat it as absent.
                _logger.LogWarning("Stripe: intent {Intent} ne postoji, kreira se novi.", payment.StripePaymentIntentId);
            }

            if (existing is not null)
            {
                if (existing.Status == "succeeded")
                {
                    await FinalizeSucceededAsync(payment);
                    return null;
                }

                // The money may still arrive for this intent; a second charge must not be started
                // and the sheet cannot be shown for it either.
                if (existing.Status == "processing")
                    throw new BusinessException("Plaćanje je u obradi — sačekajte potvrdu prije novog pokušaja.");

                var sameCharge = existing.Amount == amountMinor &&
                    string.Equals(existing.Currency, payment.Currency, StringComparison.OrdinalIgnoreCase);
                if (ReusableIntentStatuses.Contains(existing.Status) && sameCharge)
                    return existing;

                _logger.LogInformation(
                    "Rezervacija {Id}: intent {Old} u stanju '{Status}' se zamjenjuje novim.",
                    payment.ReservationId, existing.Id, existing.Status);

                // An open intent with a different amount would stay payable through its old client
                // secret; it is closed so only the replacement can be charged.
                if (CancellableIntentStatuses.Contains(existing.Status))
                {
                    try { await service.CancelAsync(existing.Id, requestOptions: requestOptions); }
                    catch (StripeException ex)
                    {
                        _logger.LogWarning(ex, "Stripe: stari intent {Intent} nije zatvoren.", existing.Id);
                    }
                }
            }
        }

        return await service.CreateAsync(new PaymentIntentCreateOptions
        {
            Amount = amountMinor,
            Currency = payment.Currency.ToLowerInvariant(),
            AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions { Enabled = true },
            Metadata = new Dictionary<string, string>
            {
                ["reservationId"] = payment.ReservationId.ToString(),
                ["reservationNumber"] = payment.Reservation.ReservationNumber
            }
        }, requestOptions);
    }

    /// <summary>Intent states the client can still pay from; anything else needs a fresh intent.</summary>
    private static readonly HashSet<string> ReusableIntentStatuses = new(StringComparer.Ordinal)
    {
        "requires_payment_method", "requires_confirmation", "requires_action"
    };

    public async Task<PaymentDto> MarkCashPaidAsync(int reservationId)
    {
        var payment = await LoadAsync(reservationId);
        EnsurePolicy(payment, PaymentAction.CollectCash);

        payment.Method = PaymentMethod.Cash;
        payment.Status = PaymentStatus.Completed;
        payment.PaidAt = DateTime.UtcNow;
        payment.PaidById = _currentUser.UserId;
        payment.UpdatedAt = DateTime.UtcNow;

        await using (var transaction = await _db.Database.BeginTransactionAsync())
        {
            await _db.SaveChangesAsync();
            await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentCompleted,
                "Plaćanje evidentirano",
                $"Gotovinsko plaćanje za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)} je evidentirano.");
            await transaction.CommitAsync();
        }

        return ToDto(payment);
    }

    /// <summary>Admin: confirms that a manual refund (cash, or a card payment with no processor
    /// reference) was physically handed back to the client.</summary>
    public async Task<PaymentDto> ConfirmCashRefundAsync(int reservationId)
    {
        var payment = await LoadAsync(reservationId);
        EnsurePolicy(payment, PaymentAction.ConfirmCashRefund);

        payment.Status = PaymentStatus.Refunded;
        payment.RefundedAmount = payment.Amount;
        payment.RefundedAt = DateTime.UtcNow;
        payment.RefundConfirmedById = _currentUser.UserId;
        payment.UpdatedAt = DateTime.UtcNow;

        await using (var transaction = await _db.Database.BeginTransactionAsync())
        {
            await _db.SaveChangesAsync();
            await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentRefunded,
                "Povrat izvršen",
                $"Povrat za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)} je izvršen.");
            await transaction.CommitAsync();
        }

        return ToDto(payment);
    }

    private PolicyOutcome EnsurePolicy(Payment payment, PaymentAction action) =>
        PaymentPolicy.EnsureAllowed(payment.Reservation.Status, payment.Status, payment.Method, action,
            PolicyContext(payment));

    private PaymentPolicy.Context PolicyContext(Payment payment) =>
        new(payment.Reservation.CompletedAt, _clock.UtcNow, payment.StripePaymentIntentId);

    public async Task<PaymentDto?> RefundAsync(int reservationId)
    {
        var payment = await _db.Payments.Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.ReservationId == reservationId);
        if (payment is null) return null;

        if (EnsurePolicy(payment, PaymentAction.Refund) == PolicyOutcome.NoOp)
        {
            // Nothing collected, or the refund is already under way. An online payment that was
            // started but never completed still has a live client secret, so the intent is closed
            // at the processor — otherwise the card could be charged for a booking that no longer
            // exists.
            await CancelOpenIntentAsync(payment);
            return ToDto(payment);
        }

        var manual = PaymentPolicy.IsManualRefund(payment.Method, payment.StripePaymentIntentId);

        // Without a key nothing can reach the processor. The attempt is recorded as failed, with the
        // reason, so the payment still shows the money is owed and the refund can be retried once
        // the key is set.
        if (!manual && !_stripe.IsConfigured)
        {
            payment.RefundRequestedAt = _clock.UtcNow;
            await MarkRefundFailedAsync(payment, "Online plaćanje nije dostupno (Stripe nije konfigurisan).");
            return ToDto(payment);
        }

        var number = ReservationNumber.Short(payment.Reservation.ReservationNumber);

        // The intent is recorded before anything leaves the process. Should the API die during the
        // provider call, the database still shows that money is owed — previously a failed refund
        // left only a log line and the payment looked settled.
        payment.Status = PaymentStatus.RefundPending;
        payment.RefundRequestedAt = _clock.UtcNow;
        payment.RefundFailureReason = null;
        payment.UpdatedAt = _clock.UtcNow;

        await using (var transaction = await _db.Database.BeginTransactionAsync())
        {
            await _db.SaveChangesAsync();
            await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentRefundPending,
                "Povrat je pokrenut",
                payment.Method == PaymentMethod.Cash
                    ? $"Povrat za rezervaciju {number} je odobren — sredstva preuzimate na recepciji."
                    : manual
                        ? $"Povrat za rezervaciju {number} je odobren — administrator će ga izvršiti ručno."
                        : $"Povrat za rezervaciju {number} je pokrenut kod platnog provajdera.");
            await transaction.CommitAsync();
        }

        // A manual refund is paid back by hand, so it stays pending until an administrator confirms it.
        if (manual)
            return ToDto(payment);

        // Only the provider call is guarded: its failure is a failed refund. Recording the answer is
        // left outside, since a database fault there says nothing about the money.
        Refund refund;
        try
        {
            refund = await new RefundService().CreateAsync(
                new RefundCreateOptions { PaymentIntent = payment.StripePaymentIntentId },
                new RequestOptions
                {
                    ApiKey = _stripe.SecretKey,
                    // Guards against a repeated call (retry, double click, reconcile) refunding twice.
                    IdempotencyKey = $"refund-{payment.Id}-{payment.RefundRequestedAt:O}"
                });
        }
        catch (StripeException ex)
        {
            _logger.LogError(ex, "Stripe: povrat nije uspio za rezervaciju {Id}.", reservationId);
            await MarkRefundFailedAsync(payment, ex.StripeError?.Message ?? ex.Message);
            return ToDto(payment);
        }
        catch (OperationCanceledException ex)
        {
            // No cancellation token is passed to the call, so this is the HTTP client giving up on a
            // slow answer. Stripe may still have created the refund, so it is not declared failed: it
            // stays pending and the sweep settles it from what Stripe reports for the intent.
            _logger.LogWarning(ex, "Povrat za rezervaciju {Id}: procesor nije odgovorio na vrijeme, stanje se naknadno provjerava.",
                reservationId);
            return ToDto(payment);
        }
        catch (Exception ex)
        {
            // A network failure is not a Stripe error, yet the outcome is the same: the money has not
            // gone back. Recorded as failed so an administrator can retry it, instead of the payment
            // sitting in "pending" with nothing to chase.
            _logger.LogError(ex, "Povrat nije stigao do procesora za rezervaciju {Id}.", reservationId);
            await MarkRefundFailedAsync(payment, "Platni provajder nije dostupan.");
            return ToDto(payment);
        }

        // Should saving fail here, the error surfaces while the payment stays pending, and the sweep
        // adopts the refund Stripe actually created.
        await ApplyRefundResultAsync(payment, refund);
        return ToDto(payment);
    }

    /// <summary>
    /// Closes a Stripe intent that was started but never paid, once the booking is cancelled. Best
    /// effort — the processor being unreachable must not stop the cancellation.
    /// </summary>
    private async Task CancelOpenIntentAsync(Payment payment)
    {
        if (payment.Reservation.Status != ReservationStatus.Cancelled ||
            payment.Method != PaymentMethod.Stripe ||
            !PaymentPolicy.CanChangeMethod(payment.Status) ||
            string.IsNullOrEmpty(payment.StripePaymentIntentId) ||
            !_stripe.IsConfigured)
            return;

        try
        {
            var service = new PaymentIntentService();
            var requestOptions = new RequestOptions { ApiKey = _stripe.SecretKey };
            var intent = await service.GetAsync(payment.StripePaymentIntentId, requestOptions: requestOptions);
            if (CancellableIntentStatuses.Contains(intent.Status))
                await service.CancelAsync(intent.Id, requestOptions: requestOptions);
        }
        catch (Exception ex)
        {
            // Includes an HTTP timeout, which Stripe.net reports as a cancellation; nothing here
            // takes a caller's cancellation token, so there is no cancellation to honour.
            _logger.LogWarning(ex, "Stripe: intent {Intent} nije zatvoren nakon otkazivanja rezervacije {Id}.",
                payment.StripePaymentIntentId, payment.ReservationId);
        }
    }

    /// <summary>Intent states Stripe still lets the caller cancel.</summary>
    private static readonly HashSet<string> CancellableIntentStatuses = new(StringComparer.Ordinal)
    {
        "requires_payment_method", "requires_confirmation", "requires_action", "requires_capture"
    };

    /// <summary>
    /// Settles the local payment against what the processor actually reports. A refund can come back
    /// as still pending, so the status is only closed when Stripe says it succeeded.
    /// </summary>
    private async Task ApplyRefundResultAsync(Payment payment, Refund refund)
    {
        payment.StripeRefundId = refund.Id;
        payment.UpdatedAt = _clock.UtcNow;

        switch (refund.Status)
        {
            case "succeeded":
                if (payment.Status == PaymentStatus.Refunded) return; // idempotent
                payment.Status = PaymentStatus.Refunded;
                payment.RefundedAmount = refund.Amount / 100m; // the amount the processor actually returned
                payment.RefundedAt = _clock.UtcNow;
                payment.RefundFailureReason = null;
                await using (var transaction = await _db.Database.BeginTransactionAsync())
                {
                    await _db.SaveChangesAsync();
                    await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentRefunded,
                        "Povrat izvršen",
                        $"Povrat za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)} je izvršen.");
                    await transaction.CommitAsync();
                }
                return;

            case "failed":
            case "canceled":
                await MarkRefundFailedAsync(payment, refund.FailureReason ?? refund.Status);
                return;

            default: // pending / requires_action — the webhook or the sweep will settle it
                await _db.SaveChangesAsync();
                return;
        }
    }

    private async Task MarkRefundFailedAsync(Payment payment, string reason)
    {
        // The webhook, the sweep and a retry can all report the same failure; the client is told
        // once, while whatever the caller stamped on the payment is still kept.
        if (payment.Status == PaymentStatus.RefundFailed && payment.RefundFailureReason == reason)
        {
            await _db.SaveChangesAsync();
            return;
        }

        payment.Status = PaymentStatus.RefundFailed;
        payment.RefundFailureReason = reason;
        payment.UpdatedAt = _clock.UtcNow;

        await using var transaction = await _db.Database.BeginTransactionAsync();
        await _db.SaveChangesAsync();
        await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentRefundFailed,
            "Povrat nije uspio",
            $"Povrat za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)} nije uspio. " +
            "Osoblje će vas kontaktirati.");
        await transaction.CommitAsync();
    }

    public async Task<int> ReconcilePendingRefundsAsync(CancellationToken cancellationToken = default)
    {
        if (!_stripe.IsConfigured) return 0;

        // Only refunds sent to the processor are chased: a manual refund waits for a person, not for
        // the processor. The PaymentIntent id is also what scopes the lookup below to this payment —
        // without it Stripe would list the refunds of the whole account.
        // The grace period outlasts one refund call to Stripe including its network retries, so a
        // request still waiting on the processor is never settled from here at the same time.
        var cutoff = _clock.UtcNow.AddMinutes(-10);
        var pending = await _db.Payments.Include(p => p.Reservation)
            .Where(p => p.Status == PaymentStatus.RefundPending &&
                        p.Method == PaymentMethod.Stripe &&
                        !string.IsNullOrEmpty(p.StripePaymentIntentId) &&
                        p.RefundRequestedAt < cutoff)
            .ToListAsync(cancellationToken);

        var settled = 0;
        var requestOptions = new RequestOptions { ApiKey = _stripe.SecretKey };
        var refunds = new RefundService();
        foreach (var payment in pending)
        {
            try
            {
                Refund? refund;
                if (payment.StripeRefundId is not null)
                {
                    refund = await refunds.GetAsync(payment.StripeRefundId, requestOptions: requestOptions,
                        cancellationToken: cancellationToken);
                }
                else
                {
                    // Pending without a refund id: the process stopped between recording the intent
                    // and hearing back from Stripe. Either the refund was created and its id lost, in
                    // which case it is adopted here, or it never left — then it is marked failed so an
                    // administrator can retry, rather than waiting for a reply that will never come.
                    var existing = await refunds.ListAsync(
                        new RefundListOptions { PaymentIntent = payment.StripePaymentIntentId, Limit = 1 },
                        requestOptions, cancellationToken);
                    refund = existing.Data.FirstOrDefault();
                    if (refund is null)
                    {
                        await MarkRefundFailedAsync(payment, "Povrat nije pokrenut kod platnog provajdera.");
                        settled++;
                        continue;
                    }
                }

                await ApplyRefundResultAsync(payment, refund);
                if (payment.Status != PaymentStatus.RefundPending) settled++;
            }
            catch (StripeException ex)
            {
                _logger.LogWarning(ex, "Stripe: provjera povrata za rezervaciju {Id} nije uspjela.", payment.ReservationId);
            }
        }
        return settled;
    }

    public async Task<int> ReconcilePendingPaymentsAsync(CancellationToken cancellationToken = default)
    {
        if (!_stripe.IsConfigured) return 0;

        // Only a succeeded intent is acted on: it is final, and completing a payment is idempotent,
        // so a sheet still open on the client is never disturbed. The window keeps abandoned
        // intents from being polled forever; a card payment is normally settled within minutes.
        var since = _clock.UtcNow.AddDays(-1);
        var pending = await _db.Payments.Include(p => p.Reservation)
            .Where(p => p.Status == PaymentStatus.Pending &&
                        p.Method == PaymentMethod.Stripe &&
                        !string.IsNullOrEmpty(p.StripePaymentIntentId) &&
                        (p.UpdatedAt ?? p.CreatedAt) > since)
            .ToListAsync(cancellationToken);

        var completed = 0;
        var requestOptions = new RequestOptions { ApiKey = _stripe.SecretKey };
        var intents = new PaymentIntentService();
        foreach (var payment in pending)
        {
            try
            {
                var intent = await intents.GetAsync(payment.StripePaymentIntentId, requestOptions: requestOptions,
                    cancellationToken: cancellationToken);
                if (intent.Status != "succeeded") continue;

                await FinalizeSucceededAsync(payment);
                completed++;
            }
            catch (StripeException ex)
            {
                _logger.LogWarning(ex, "Stripe: provjera plaćanja za rezervaciju {Id} nije uspjela.", payment.ReservationId);
            }
        }
        return completed;
    }

    public async Task HandleWebhookAsync(string json, string signature)
    {
        if (string.IsNullOrWhiteSpace(_stripe.WebhookSecret))
            throw new BusinessException("Stripe webhook nije konfigurisan (nedostaje STRIPE_WEBHOOK_SECRET).");

        Event stripeEvent;
        try
        {
            stripeEvent = EventUtility.ConstructEvent(json, signature, _stripe.WebhookSecret);
        }
        catch (StripeException ex)
        {
            _logger.LogWarning(ex, "Stripe webhook: nevalidan potpis.");
            throw new BusinessException("Nevalidan Stripe potpis.");
        }

        switch (stripeEvent.Data.Object)
        {
            case PaymentIntent intent:
                await HandleIntentEventAsync(stripeEvent.Type, intent);
                break;

            // Refunds settle asynchronously, so their final state arrives as its own event.
            case Refund refund:
                await HandleRefundEventAsync(refund);
                break;
        }
    }

    private async Task HandleIntentEventAsync(string eventType, PaymentIntent intent)
    {
        var payment = await _db.Payments.Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.StripePaymentIntentId == intent.Id);
        if (payment is null)
        {
            _logger.LogWarning("Stripe webhook: nepoznat PaymentIntent {Id}.", intent.Id);
            return;
        }

        switch (eventType)
        {
            case "payment_intent.succeeded":
                await FinalizeSucceededAsync(payment);
                break;

            case "payment_intent.payment_failed":
                payment.Status = PaymentStatus.Failed;
                payment.UpdatedAt = _clock.UtcNow;
                await _db.SaveChangesAsync();
                break;
        }
    }

    private async Task HandleRefundEventAsync(Refund refund)
    {
        // A refund without a PaymentIntent is matched by its own id only; comparing a null intent
        // would pick up any payment that never had one.
        var intentId = refund.PaymentIntentId;
        var payment = await _db.Payments.Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.StripeRefundId == refund.Id ||
                                      (intentId != null && p.StripePaymentIntentId == intentId));
        if (payment is null)
        {
            _logger.LogWarning("Stripe webhook: nepoznat povrat {Id}.", refund.Id);
            return;
        }

        await ApplyRefundResultAsync(payment, refund);
    }

    public async Task<PaymentDto> VerifyAsync(int reservationId)
    {
        var payment = await LoadAsync(reservationId);
        EnsureOwnerOrAdmin(payment.Reservation);
        EnsureStripeConfigured();

        if (payment.Status == PaymentStatus.Completed) return ToDto(payment);
        if (string.IsNullOrEmpty(payment.StripePaymentIntentId))
            throw new BusinessException("Rezervacija nema pokrenuto online plaćanje.");

        PaymentIntent intent;
        try
        {
            intent = await new PaymentIntentService().GetAsync(payment.StripePaymentIntentId,
                requestOptions: new RequestOptions { ApiKey = _stripe.SecretKey });
        }
        catch (StripeException ex)
        {
            // A provider failure is reported as a business error (400) with Stripe's message, not as a 500.
            _logger.LogWarning(ex, "Stripe: provjera plaćanja nije uspjela za rezervaciju {Id}.", reservationId);
            throw new BusinessException($"Stripe greška: {ex.StripeError?.Message ?? ex.Message}");
        }

        switch (intent.Status)
        {
            case "succeeded":
                await FinalizeSucceededAsync(payment);
                break;

            case "canceled":
                payment.Status = PaymentStatus.Failed;
                payment.UpdatedAt = _clock.UtcNow;
                await _db.SaveChangesAsync();
                break;

            // The client closed the sheet after a declined card: the attempt failed, but the intent
            // stays reusable so paying again works.
            case "requires_payment_method" when intent.LastPaymentError is not null:
                payment.Status = PaymentStatus.Failed;
                payment.UpdatedAt = _clock.UtcNow;
                await _db.SaveChangesAsync();
                break;

            // processing / requires_action / requires_confirmation: the money may still arrive, so
            // nothing is decided here — the webhook or a later verify closes it.
        }

        var dto = ToDto(payment);
        dto.ProcessorStatus = intent.Status;
        dto.IsFinal = payment.Status is PaymentStatus.Completed or PaymentStatus.Failed
            or PaymentStatus.Refunded or PaymentStatus.RefundFailed;
        return dto;
    }

    /// <summary>
    /// Marks an online payment as collected and notifies the client. Reached from two
    /// directions — the Stripe webhook and the client-triggered verification — so it is
    /// idempotent: once completed, calling it again changes nothing.
    /// </summary>
    private async Task FinalizeSucceededAsync(Payment payment)
    {
        if (payment.Status == PaymentStatus.Completed) return;

        payment.Status = PaymentStatus.Completed;
        payment.PaidAt = _clock.UtcNow;
        payment.UpdatedAt = _clock.UtcNow;

        await using (var transaction = await _db.Database.BeginTransactionAsync())
        {
            await _db.SaveChangesAsync();
            await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentCompleted,
                "Plaćanje uspješno",
                $"Online plaćanje za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)} je zaprimljeno.");
            await transaction.CommitAsync();
        }

        // The charge landed after the booking was cancelled (the sheet was open while an
        // administrator or the sweep cancelled it). The admin sees a refundable payment; this
        // makes the situation visible in the log as well.
        if (payment.Reservation.Status == ReservationStatus.Cancelled)
            _logger.LogWarning("Rezervacija {Id} je otkazana, a plaćanje je naknadno zaprimljeno — potreban je povrat.",
                payment.ReservationId);
    }

    private async Task<Payment> LoadAsync(int reservationId)
    {
        var reservation = await _db.Reservations.Include(r => r.Payment)
            .FirstOrDefaultAsync(r => r.Id == reservationId)
            ?? throw new NotFoundException("Rezervacija", reservationId);

        return reservation.Payment
            ?? throw new BusinessException("Rezervacija nema evidentirano plaćanje.");
    }

    private void EnsureOwnerOrAdmin(Reservation reservation)
    {
        if (!_currentUser.IsAdmin && reservation.ClientId != _currentUser.UserId)
            throw new ForbiddenException("Nemate pristup ovoj rezervaciji.");
    }

    private void EnsureStripeConfigured()
    {
        if (!_stripe.IsConfigured)
            throw new BusinessException("Online plaćanje nije dostupno (Stripe nije konfigurisan).");
    }

    private PaymentDto ToDto(Payment p)
    {
        var reservation = p.Reservation.Status;
        var context = PolicyContext(p);

        return new PaymentDto
        {
            ReservationId = p.ReservationId,
            Method = p.Method,
            Amount = p.Amount,
            Currency = p.Currency,
            Status = p.Status,
            StripePaymentIntentId = p.StripePaymentIntentId,
            PaidAt = p.PaidAt,
            RefundedAmount = p.RefundedAmount,
            RefundedAt = p.RefundedAt,
            StripeRefundId = p.StripeRefundId,
            RefundRequestedAt = p.RefundRequestedAt,
            RefundFailureReason = p.RefundFailureReason,
            CanCollectCash = PaymentPolicy.IsAllowed(reservation, p.Status, p.Method,
                PaymentAction.CollectCash, context),
            CanStartOnlinePayment = _stripe.IsConfigured && PaymentPolicy.IsAllowed(reservation, p.Status,
                p.Method, PaymentAction.StartOnlinePayment, context),
            CanRefund = PaymentPolicy.IsAllowed(reservation, p.Status, p.Method,
                PaymentAction.Refund, context),
            CanConfirmCashRefund = PaymentPolicy.IsAllowed(reservation, p.Status, p.Method,
                PaymentAction.ConfirmCashRefund, context)
        };
    }
}
