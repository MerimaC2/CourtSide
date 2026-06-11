using CourtSide.Services.Reports;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = Roles.Admin)]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reports;

    public ReportsController(IReportService reports) => _reports = reports;

    /// <summary>Reservations + revenue PDF report for a period (optional sport-center filter).</summary>
    [HttpGet("reservations")]
    public async Task<IActionResult> Reservations(
        [FromQuery] DateOnly? dateFrom, [FromQuery] DateOnly? dateTo, [FromQuery] int? sportCenterId)
    {
        var pdf = await _reports.ReservationsPdfAsync(dateFrom, dateTo, sportCenterId);
        return File(pdf, "application/pdf", $"rezervacije_{DateTime.UtcNow:yyyyMMdd_HHmm}.pdf");
    }
}
