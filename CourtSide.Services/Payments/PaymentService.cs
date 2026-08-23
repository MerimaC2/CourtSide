using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Core.Helpers;
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

    /// <summary>Refunds a completed payment (Stripe API for online, status-only for cash). No-op if nothing to refund.</summary>
    Task<PaymentDto?> RefundAsync(int reservationId);

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
    private readonly ILogger<PaymentService> _logger;

    public PaymentService(DatabaseContext db, IOptions<StripeSettings> stripe, ICurrentUser currentUser,
        INotificationService notifications, ILogger<PaymentService> logger)
    {
        _db = db;
        _stripe = stripe.Value;
        _currentUser = currentUser;
        _notifications = notifications;
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

        if (payment.Status == PaymentStatus.Completed)
            throw new BusinessException("Rezervacija je već plaćena.");

        var requestOptions = new RequestOptions { ApiKey = _stripe.SecretKey };
        var service = new PaymentIntentService();
        var amountMinor = (long)Math.Round(payment.Amount * 100m, MidpointRounding.AwayFromZero);

        try
        {
            PaymentIntent intent;
            if (!string.IsNullOrEmpty(payment.StripePaymentIntentId))
            {
                intent = await service.GetAsync(payment.StripePaymentIntentId, requestOptions: requestOptions);
            }
            else
            {
                intent = await service.CreateAsync(new PaymentIntentCreateOptions
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

    public async Task<PaymentDto> MarkCashPaidAsync(int reservationId)
    {
        var payment = await LoadAsync(reservationId);

        if (payment.Status == PaymentStatus.Completed)
            throw new BusinessException("Rezervacija je već plaćena.");
        if (payment.Status == PaymentStatus.Refunded)
            throw new BusinessException("Plaćanje je već refundirano.");

        payment.Method = PaymentMethod.Cash;
        payment.Status = PaymentStatus.Completed;
        payment.PaidAt = DateTime.UtcNow;
        payment.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentCompleted,
            "Plaćanje evidentirano",
            $"Gotovinsko plaćanje za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)} je evidentirano.");

        return ToDto(payment);
    }

    public async Task<PaymentDto?> RefundAsync(int reservationId)
    {
        var payment = await _db.Payments.Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.ReservationId == reservationId);
        if (payment is null || payment.Status != PaymentStatus.Completed)
            return null; // nothing collected → nothing to refund

        if (payment.Method == PaymentMethod.Stripe && !string.IsNullOrEmpty(payment.StripePaymentIntentId))
        {
            EnsureStripeConfigured();
            try
            {
                await new RefundService().CreateAsync(
                    new RefundCreateOptions { PaymentIntent = payment.StripePaymentIntentId },
                    new RequestOptions { ApiKey = _stripe.SecretKey });
            }
            catch (StripeException ex)
            {
                _logger.LogWarning(ex, "Stripe: refund nije uspio za rezervaciju {Id}.", reservationId);
                throw new BusinessException($"Stripe greška pri povratu: {ex.StripeError?.Message ?? ex.Message}");
            }
        }

        payment.Status = PaymentStatus.Refunded;
        payment.RefundedAmount = payment.Amount;
        payment.RefundedAt = DateTime.UtcNow;
        payment.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        await _notifications.CreateAsync(payment.Reservation.ClientId, NotificationType.PaymentRefunded,
            "Povrat sredstava",
            $"Izvršen je povrat za rezervaciju {ReservationNumber.Short(payment.Reservation.ReservationNumber)}.");

        return ToDto(payment);
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

        if (stripeEvent.Data.Object is not PaymentIntent intent)
            return;

        var payment = await _db.Payments.Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.StripePaymentIntentId == intent.Id);
        if (payment is null)
        {
            _logger.LogWarning("Stripe webhook: nepoznat PaymentIntent {Id}.", intent.Id);
            return;
        }

        switch (stripeEvent.Type)
        {
            case "payment_intent.succeeded":
                await FinalizeSucceededAsync(payment);
                break;

            case "payment_intent.payment_failed":
                payment.Status = PaymentStatus.Failed;
                payment.UpdatedAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();
                break;
        }
    }

    public async Task<PaymentDto> VerifyAsync(int reservationId)
    {
        EnsureStripeConfigured();
        var payment = await LoadAsync(reservationId);
        EnsureOwnerOrAdmin(payment.Reservation);

        if (payment.Status == PaymentStatus.Completed) return ToDto(payment);
        if (string.IsNullOrEmpty(payment.StripePaymentIntentId))
            throw new BusinessException("Rezervacija nema pokrenuto online plaćanje.");

        var service = new PaymentIntentService();
        var intent = await service.GetAsync(payment.StripePaymentIntentId,
            requestOptions: new RequestOptions { ApiKey = _stripe.SecretKey });

        if (intent.Status == "succeeded")
        {
            await FinalizeSucceededAsync(payment);
        }
        else if (intent.Status == "canceled")
        {
            payment.Status = PaymentStatus.Failed;
            payment.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        return ToDto(payment);
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
            throw new BusinessException("Nemate pristup ovoj rezervaciji.");
    }

    private void EnsureStripeConfigured()
    {
        if (!_stripe.IsConfigured)
            throw new BusinessException("Online plaćanje nije dostupno (Stripe nije konfigurisan).");
    }

    private static PaymentDto ToDto(Payment p) => new()
    {
        ReservationId = p.ReservationId,
        Method = p.Method,
        Amount = p.Amount,
        Currency = p.Currency,
        Status = p.Status,
        StripePaymentIntentId = p.StripePaymentIntentId,
        PaidAt = p.PaidAt,
        RefundedAmount = p.RefundedAmount,
        RefundedAt = p.RefundedAt
    };
}
