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

    /// <summary>Starts a refund of a collected payment. Online refunds settle against Stripe; cash
    /// refunds stay pending until an administrator confirms the money was handed back. No-op if
    /// nothing was collected.</summary>
    Task<PaymentDto?> RefundAsync(int reservationId);

    /// <summary>Admin: confirms that a cash refund was physically paid out.</summary>
    Task<PaymentDto> ConfirmCashRefundAsync(int reservationId);

    /// <summary>Settles online refunds still pending at the processor. Returns how many closed.</summary>
    Task<int> ReconcilePendingRefundsAsync(CancellationToken cancellationToken = default);

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
        EnsureStripeConfigured();

        var payment = await LoadAsync(reservationId);
        EnsureOwnerOrAdmin(payment.Reservation);
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

                var sameCharge = existing.Amount == amountMinor &&
                    string.Equals(existing.Currency, payment.Currency, StringComparison.OrdinalIgnoreCase);
                if (ReusableIntentStatuses.Contains(existing.Status) && sameCharge)
                    return existing;

                _logger.LogInformation(
                    "Rezervacija {Id}: intent {Old} u stanju '{Status}' se zamjenjuje novim.",
                    payment.ReservationId, existing.Id, existing.Status);
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
        "requires_payment_method", "requires_confirmation", "requires_action", "processing"
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

    /// <summary>Admin: confirms that cash was physically handed back to the client.</summary>
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
        new(payment.Reservation.CompletedAt, _clock.UtcNow);

    public async Task<PaymentDto?> RefundAsync(int reservationId)
    {
        var payment = await _db.Payments.Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.ReservationId == reservationId);
        if (payment is null) return null;

        if (EnsurePolicy(payment, PaymentAction.Refund) == PolicyOutcome.NoOp)
            return ToDto(payment); // nothing collected, or the refund is already under way

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
                    : $"Povrat za rezervaciju {number} je pokrenut kod platnog provajdera.");
            await transaction.CommitAsync();
        }

        // Cash leaves the till by hand, so it stays pending until an administrator confirms it.
        if (payment.Method == PaymentMethod.Cash || string.IsNullOrEmpty(payment.StripePaymentIntentId))
            return ToDto(payment);

        EnsureStripeConfigured();
        try
        {
            var refund = await new RefundService().CreateAsync(
                new RefundCreateOptions { PaymentIntent = payment.StripePaymentIntentId },
                new RequestOptions
                {
                    ApiKey = _stripe.SecretKey,
                    // Guards against a repeated call (retry, double click, reconcile) refunding twice.
                    IdempotencyKey = $"refund-{payment.Id}-{payment.RefundRequestedAt:O}"
                });

            await ApplyRefundResultAsync(payment, refund);
        }
        catch (StripeException ex)
        {
            _logger.LogError(ex, "Stripe: povrat nije uspio za rezervaciju {Id}.", reservationId);
            await MarkRefundFailedAsync(payment, ex.StripeError?.Message ?? ex.Message);
        }

        return ToDto(payment);
    }

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
                        $"Izvršen je povrat za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)}.");
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

        // Only online refunds are chased: a cash refund waits for a person, not for the processor.
        var cutoff = _clock.UtcNow.AddMinutes(-2);
        var pending = await _db.Payments.Include(p => p.Reservation)
            .Where(p => p.Status == PaymentStatus.RefundPending &&
                        p.Method == PaymentMethod.Stripe &&
                        p.StripeRefundId != null &&
                        p.RefundRequestedAt < cutoff)
            .ToListAsync(cancellationToken);

        var settled = 0;
        foreach (var payment in pending)
        {
            try
            {
                var refund = await new RefundService().GetAsync(payment.StripeRefundId!,
                    requestOptions: new RequestOptions { ApiKey = _stripe.SecretKey },
                    cancellationToken: cancellationToken);
                await ApplyRefundResultAsync(payment, refund);
                if (payment.Status != PaymentStatus.RefundPending) settled++;
            }
            catch (StripeException ex)
            {
                _logger.LogWarning(ex, "Stripe: provjera povrata {Refund} nije uspjela.", payment.StripeRefundId);
            }
        }
        return settled;
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
        var payment = await _db.Payments.Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.StripeRefundId == refund.Id ||
                                      p.StripePaymentIntentId == refund.PaymentIntentId);
        if (payment is null)
        {
            _logger.LogWarning("Stripe webhook: nepoznat povrat {Id}.", refund.Id);
            return;
        }

        await ApplyRefundResultAsync(payment, refund);
    }

    public async Task<PaymentDto> VerifyAsync(int reservationId)
    {
        EnsureStripeConfigured();
        var payment = await LoadAsync(reservationId);
        EnsureOwnerOrAdmin(payment.Reservation);

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
            // Without this the provider's failure would surface as a 500, as if the API were broken.
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
        payment.PaidAt = DateTime.UtcNow;
        payment.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentCompleted,
            "Plaćanje uspješno",
            $"Online plaćanje za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)} je zaprimljeno.");
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
