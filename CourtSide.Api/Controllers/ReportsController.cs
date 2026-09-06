using CourtSide.Services.Reports;
using CourtSide.Shared.Constants;
using CourtSide.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = Roles.Admin)]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reports;
    private readonly IAppClock _clock;

    public ReportsController(IReportService reports, IAppClock clock)
    {
        _reports = reports;
        _clock = clock;
    }

    /// <summary>Reservations + revenue PDF report for a period (optional sport-center filter).</summary>
    [HttpGet("reservations")]
    public async Task<IActionResult> Reservations(
        [FromQuery] DateOnly? dateFrom, [FromQuery] DateOnly? dateTo, [FromQuery] int? sportCenterId,
        [FromQuery] string? language = null)
    {
        // The report is rendered server-side, so the client passes the language it is
        // currently displaying in.
        var pdf = await _reports.ReservationsPdfAsync(dateFrom, dateTo, sportCenterId, language);
        return File(pdf, "application/pdf", $"rezervacije_{_clock.LocalNow:yyyyMMdd_HHmm}.pdf");
    }

    /// <summary>Court occupancy PDF: most requested slots and occupancy per court.</summary>
    [HttpGet("occupancy")]
    public async Task<IActionResult> Occupancy(
        [FromQuery] DateOnly? dateFrom, [FromQuery] DateOnly? dateTo, [FromQuery] int? sportCenterId,
        [FromQuery] string? language = null)
    {
        var pdf = await _reports.OccupancyPdfAsync(dateFrom, dateTo, sportCenterId, language);
        return File(pdf, "application/pdf", $"popunjenost_{_clock.LocalNow:yyyyMMdd_HHmm}.pdf");
    }
}
