using CourtSide.Core.Dto;
using CourtSide.Services.Payments;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _payments;

    public PaymentsController(IPaymentService payments) => _payments = payments;

    /// <summary>Current payment state for a reservation (owner or admin).</summary>
    [HttpGet("{reservationId:int}")]
    public async Task<ActionResult<PaymentDto>> Get(int reservationId)
        => Ok(await _payments.GetByReservationAsync(reservationId));

    /// <summary>Starts an online (Stripe) payment and returns the client secret to complete it.</summary>
    [HttpPost("{reservationId:int}/intent")]
    public async Task<ActionResult<PaymentIntentDto>> CreateIntent(int reservationId)
        => Ok(await _payments.CreateIntentAsync(reservationId));

    /// <summary>Admin: record on-site cash payment.</summary>
    /// <summary>Client-triggered check of an online payment's status with Stripe (finalizes if succeeded).</summary>
    [HttpPost("{reservationId:int}/verify")]
    public async Task<ActionResult<PaymentDto>> Verify(int reservationId)
        => Ok(await _payments.VerifyAsync(reservationId));

    [HttpPost("{reservationId:int}/cash")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<PaymentDto>> MarkCashPaid(int reservationId)
        => Ok(await _payments.MarkCashPaidAsync(reservationId));

    /// <summary>Admin: refund a completed payment.</summary>
    [HttpPost("{reservationId:int}/refund")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<PaymentDto>> Refund(int reservationId)
    {
        var result = await _payments.RefundAsync(reservationId);
        return result is null ? NoContent() : Ok(result);
    }

    /// <summary>Stripe webhook (payment confirmations). Verified via the Stripe-Signature header.</summary>
    [HttpPost("webhook")]
    [AllowAnonymous]
    public async Task<IActionResult> Webhook()
    {
        using var reader = new StreamReader(Request.Body);
        var json = await reader.ReadToEndAsync();
        await _payments.HandleWebhookAsync(json, Request.Headers["Stripe-Signature"]!);
        return Ok();
    }
}
