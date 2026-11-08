using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Core.Helpers;
using CourtSide.Infrastructure;
using CourtSide.Shared.Services;
using Microsoft.EntityFrameworkCore;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace CourtSide.Services.Reports;

public interface IReportService
{
    /// <summary>Builds a reservations + revenue PDF report for the given period/center (admin).</summary>
    Task<byte[]> ReservationsPdfAsync(DateOnly? dateFrom, DateOnly? dateTo, int? sportCenterId,
        string? language = null);

    /// <summary>Builds a court occupancy PDF (most requested slots, occupancy per court).</summary>
    Task<byte[]> OccupancyPdfAsync(DateOnly? dateFrom, DateOnly? dateTo, int? sportCenterId,
        string? language = null);
}

/// <summary>Generates PDF reports with QuestPDF.</summary>
public class ReportService : IReportService
{
    static ReportService() => QuestPDF.Settings.License = LicenseType.Community;

    private readonly DatabaseContext _db;
    private readonly IAppClock _clock;

    public ReportService(DatabaseContext db, IAppClock clock)
    {
        _db = db;
        _clock = clock;
    }

    /// <summary>
    /// A reversed period matches nothing, so the report came out empty and read as "no bookings"
    /// instead of as a mistake in the filter.
    /// </summary>
    private static void EnsureValidPeriod(DateOnly? dateFrom, DateOnly? dateTo)
    {
        if (dateFrom.HasValue && dateTo.HasValue && dateFrom > dateTo)
            throw new BusinessException("Datum „od“ ne može biti poslije datuma „do“.");
    }

    /// <summary>
    /// How many of the court's slots on that date the blocks take away. Availability shows every
    /// slot a block overlaps as blocked, so exactly those slots are taken off the available total,
    /// each counted once even where blocks overlap; on a day the court is closed there are no
    /// slots and nothing is taken away.
    /// </summary>
    private static int BlockedSlots(Court court, DateOnly date, IEnumerable<(TimeOnly Start, TimeOnly End)> blocks)
    {
        var day = court.WorkingHours.FirstOrDefault(w => w.DayOfWeek == date.DayOfWeek);
        if (day is null) return 0;

        return SlotGrid.Build(day.OpenTime, day.CloseTime)
            .Count(slot => blocks.Any(b => SlotGrid.Overlaps(b.Start, b.End, slot.Start, slot.End)));
    }

    public async Task<byte[]> ReservationsPdfAsync(DateOnly? dateFrom, DateOnly? dateTo, int? sportCenterId,
        string? language = null)
    {
        EnsureValidPeriod(dateFrom, dateTo);
        var labels = ReportLabels.For(language);

        // Filtered reports name the centre in the header; an unfiltered one covers all centres.
        var centerName = sportCenterId.HasValue
            ? await _db.SportCenters.Where(s => s.Id == sportCenterId.Value)
                .Select(s => s.Name).FirstOrDefaultAsync()
            : null;

        var query = _db.Reservations
            .Include(r => r.Court).ThenInclude(c => c.SportCenter)
            .Include(r => r.Client)
            .Include(r => r.Payment)
            .AsQueryable();

        if (dateFrom.HasValue) query = query.Where(r => r.Date >= dateFrom.Value);
        if (dateTo.HasValue) query = query.Where(r => r.Date <= dateTo.Value);
        if (sportCenterId.HasValue) query = query.Where(r => r.Court.SportCenterId == sportCenterId.Value);

        var reservations = await query
            .OrderBy(r => r.Date).ThenBy(r => r.StartTime)
            .ToListAsync();

        var statusCounts = reservations
            .GroupBy(r => r.Status)
            .ToDictionary(g => g.Key, g => g.Count());

        bool Paid(Core.Entities.Reservation r) => r.Payment is { Status: PaymentStatus.Completed };
        var collectedRevenue = reservations.Where(Paid).Sum(r => r.Payment!.Amount);
        var paidCount = reservations.Count(Paid);

        var perCourt = reservations
            .GroupBy(r => new { r.CourtId, r.Court.Name, Center = r.Court.SportCenter.Name })
            .Select(g => new
            {
                g.Key.Name,
                g.Key.Center,
                Count = g.Count(),
                Revenue = g.Where(Paid).Sum(r => r.Payment!.Amount)
            })
            .OrderByDescending(x => x.Revenue).ThenByDescending(x => x.Count)
            .ToList();

        // An open bound is shown as the first or last date the listed reservations fall on
        // (they are ordered by date), so the header states the range the report really covers.
        var periodFrom = dateFrom ?? reservations.FirstOrDefault()?.Date;
        var periodTo = dateTo ?? reservations.LastOrDefault()?.Date;
        var periodText = $"{periodFrom?.ToString("dd.MM.yyyy") ?? "—"} – {periodTo?.ToString("dd.MM.yyyy") ?? "—"}";
        var generatedAt = _clock.LocalNow.ToString("dd.MM.yyyy HH:mm");

        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(28);
                page.DefaultTextStyle(x => x.FontSize(10).FontColor("#222222"));

                page.Header().Column(header =>
                {
                    header.Item().Row(row =>
                    {
                        row.RelativeItem().Column(c =>
                        {
                            c.Item().Text("CourtSide").Bold().FontSize(20).FontColor("#1A5276");
                            c.Item().Text(labels.Subtitle).FontSize(12).FontColor("#555555");
                        });
                        row.ConstantItem(180).AlignRight().Column(c =>
                        {
                            if (centerName != null)
                                c.Item().Text($"{labels.Centre}: {centerName}").SemiBold();
                            c.Item().Text($"{labels.Period}: {periodText}");
                            c.Item().Text($"{labels.GeneratedAt}: {generatedAt}").FontColor("#777777");
                        });
                    });
                    header.Item().PaddingTop(6).LineHorizontal(1).LineColor("#1A5276");
                });

                page.Content().PaddingVertical(10).Column(content =>
                {
                    content.Spacing(14);

                    // ----- Sažetak -----
                    content.Item().Column(c =>
                    {
                        c.Item().Text(labels.Summary).Bold().FontSize(13);
                        c.Item().PaddingTop(4).Row(row =>
                        {
                            row.RelativeItem().Column(s =>
                            {
                                s.Item().Text($"{labels.TotalReservations}: {reservations.Count}");
                                foreach (var status in Enum.GetValues<ReservationStatus>())
                                    s.Item().Text($"  • {labels.Statuses[status]}: {(statusCounts.TryGetValue(status, out var n) ? n : 0)}");
                            });
                            row.RelativeItem().Column(s =>
                            {
                                s.Item().Text($"{labels.CollectedRevenue}: {collectedRevenue:N2} BAM").Bold().FontColor("#1E8449");
                                s.Item().Text($"{labels.PaidReservations}: {paidCount}");
                            });
                        });
                    });

                    // ----- Po terenu -----
                    content.Item().Column(c =>
                    {
                        c.Item().Text(labels.ByCourt).Bold().FontSize(13);
                        c.Item().PaddingTop(4).Table(table =>
                        {
                            table.ColumnsDefinition(cols =>
                            {
                                cols.RelativeColumn(3);
                                cols.RelativeColumn(3);
                                cols.RelativeColumn(2);
                                cols.RelativeColumn(2);
                            });
                            table.Header(h =>
                            {
                                HeaderCell(h.Cell(), labels.Court);
                                HeaderCell(h.Cell(), labels.Centre);
                                HeaderCell(h.Cell(), labels.ReservationCount);
                                HeaderCell(h.Cell(), labels.Collected);
                            });
                            foreach (var c2 in perCourt)
                            {
                                BodyCell(table.Cell(), c2.Name);
                                BodyCell(table.Cell(), c2.Center);
                                BodyCell(table.Cell(), c2.Count.ToString());
                                BodyCell(table.Cell(), $"{c2.Revenue:N2}");
                            }
                            if (perCourt.Count == 0)
                                table.Cell().ColumnSpan(4).Element(e => e.Padding(4)).Text(labels.NoDataForPeriod).Italic();
                        });
                    });

                    // ----- Lista rezervacija -----
                    content.Item().Column(c =>
                    {
                        c.Item().Text(labels.Reservations).Bold().FontSize(13);
                        c.Item().PaddingTop(4).Table(table =>
                        {
                            table.ColumnsDefinition(cols =>
                            {
                                cols.RelativeColumn(3);
                                cols.RelativeColumn(2);
                                cols.RelativeColumn(2);
                                cols.RelativeColumn(3);
                                cols.RelativeColumn(3);
                                cols.RelativeColumn(2);
                                cols.RelativeColumn(2);
                            });
                            table.Header(h =>
                            {
                                HeaderCell(h.Cell(), labels.Number);
                                HeaderCell(h.Cell(), labels.Date);
                                HeaderCell(h.Cell(), labels.Slot);
                                HeaderCell(h.Cell(), labels.Court);
                                HeaderCell(h.Cell(), labels.Client);
                                HeaderCell(h.Cell(), labels.Status);
                                HeaderCell(h.Cell(), labels.Paid);
                            });
                            foreach (var r in reservations)
                            {
                                BodyCell(table.Cell(), ReservationNumber.Short(r.ReservationNumber));
                                BodyCell(table.Cell(), r.Date.ToString("dd.MM.yyyy"));
                                BodyCell(table.Cell(), $"{r.StartTime:HH\\:mm}-{r.EndTime:HH\\:mm}");
                                BodyCell(table.Cell(), r.Court.Name);
                                BodyCell(table.Cell(), $"{r.Client.FirstName} {r.Client.LastName}");
                                BodyCell(table.Cell(), labels.Statuses[r.Status]);
                                BodyCell(table.Cell(), Paid(r) ? labels.Yes : labels.No);
                            }
                            if (reservations.Count == 0)
                                table.Cell().ColumnSpan(7).Element(e => e.Padding(4)).Text(labels.NoReservationsForPeriod).Italic();
                        });
                    });
                });

                page.Footer().AlignCenter().Text(text =>
                {
                    text.Span(labels.Page);
                    text.CurrentPageNumber();
                    text.Span(" / ");
                    text.TotalPages();
                });
            });
        });

        return document.GeneratePdf();
    }

    public async Task<byte[]> OccupancyPdfAsync(DateOnly? dateFrom, DateOnly? dateTo, int? sportCenterId,
        string? language = null)
    {
        EnsureValidPeriod(dateFrom, dateTo);
        var labels = ReportLabels.For(language);

        // Filtered reports name the centre in the header; an unfiltered one covers all centres.
        var centerName = sportCenterId.HasValue
            ? await _db.SportCenters.Where(s => s.Id == sportCenterId.Value)
                .Select(s => s.Name).FirstOrDefaultAsync()
            : null;

        // Occupancy needs a bounded period so available hours can be computed;
        // when none is given the report covers the last 30 days.
        // A start alone runs until today, or 30 days ahead when the start itself is in the
        // future, so a future start on its own still gives a valid period. An end alone covers
        // the 30 days before it.
        var today = _clock.Today;
        var to = dateTo ?? (dateFrom.HasValue && dateFrom.Value > today ? dateFrom.Value.AddDays(29) : today);
        var from = dateFrom ?? to.AddDays(-29);
        // The resolved period is validated, so a start after the end is refused rather than
        // producing a report where every court reads as empty.
        EnsureValidPeriod(from, to);

        var courtsQuery = _db.Courts
            .Include(c => c.SportCenter)
            .Include(c => c.WorkingHours)
            .AsQueryable();
        if (sportCenterId.HasValue)
            courtsQuery = courtsQuery.Where(c => c.SportCenterId == sportCenterId.Value);
        var courts = await courtsQuery.OrderBy(c => c.Name).ToListAsync();

        var reservations = await _db.Reservations
            .Where(r => r.Date >= from && r.Date <= to && r.Status != ReservationStatus.Cancelled)
            .Where(r => !sportCenterId.HasValue || r.Court.SportCenterId == sportCenterId.Value)
            .Select(r => new { r.CourtId, r.StartTime, r.EndTime })
            .ToListAsync();

        // Hours the court was deliberately taken out of service are hours nobody could have
        // booked, so they belong on neither side of the ratio.
        var blocks = await _db.CourtAvailabilityBlocks
            .Where(b => b.Date >= from && b.Date <= to)
            .Where(b => !sportCenterId.HasValue || b.Court.SportCenterId == sportCenterId.Value)
            .Select(b => new { b.CourtId, b.Date, b.StartTime, b.EndTime })
            .ToListAsync();

        var topSlots = reservations
            .GroupBy(r => r.StartTime)
            .Select(g => new { Start = g.Key, Count = g.Count() })
            .OrderByDescending(x => x.Count).ThenBy(x => x.Start)
            .Take(10)
            .ToList();

        // How many times each day of the week occurs in the period, so a court's
        // weekly opening hours scale to the whole period.
        var daysPerDayOfWeek = new int[7];
        for (var day = from; day <= to; day = day.AddDays(1))
            daysPerDayOfWeek[(int)day.DayOfWeek]++;

        var slotHours = SlotGrid.SlotDuration.TotalHours;
        var occupancyRows = courts.Select(court =>
        {
            // Capacity is what availability actually offers: whole slots from the same grid, so
            // time before closing that is too short for a slot is not counted as bookable.
            var offeredHours = slotHours * court.WorkingHours.Sum(w =>
                daysPerDayOfWeek[(int)w.DayOfWeek] * SlotGrid.Build(w.OpenTime, w.CloseTime).Count());
            var blockedHours = slotHours * blocks
                .Where(b => b.CourtId == court.Id)
                .GroupBy(b => b.Date)
                .Sum(g => BlockedSlots(court, g.Key, g.Select(b => (b.StartTime, b.EndTime))));
            var available = Math.Max(0, offeredHours - blockedHours);
            var reserved = reservations
                .Where(r => r.CourtId == court.Id)
                .Sum(r => (r.EndTime - r.StartTime).TotalHours);
            return new
            {
                court.Name,
                Center = court.SportCenter.Name,
                Count = reservations.Count(r => r.CourtId == court.Id),
                Reserved = reserved,
                Available = available,
                // Capped at 100 %: working hours can be narrowed after a booking was made.
                Occupancy = available > 0 ? Math.Clamp(reserved / available, 0, 1) : 0
            };
        })
        .OrderByDescending(x => x.Occupancy).ThenByDescending(x => x.Count)
        .ToList();

        var periodText = $"{from:dd.MM.yyyy} – {to:dd.MM.yyyy}";
        var generatedAt = _clock.LocalNow.ToString("dd.MM.yyyy HH:mm");

        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(28);
                page.DefaultTextStyle(x => x.FontSize(10).FontColor("#222222"));

                page.Header().Column(header =>
                {
                    header.Item().Row(row =>
                    {
                        row.RelativeItem().Column(c =>
                        {
                            c.Item().Text("CourtSide").Bold().FontSize(20).FontColor("#1A5276");
                            c.Item().Text(labels.OccupancySubtitle).FontSize(12).FontColor("#555555");
                        });
                        row.ConstantItem(180).AlignRight().Column(c =>
                        {
                            if (centerName != null)
                                c.Item().Text($"{labels.Centre}: {centerName}").SemiBold();
                            c.Item().Text($"{labels.Period}: {periodText}");
                            c.Item().Text($"{labels.GeneratedAt}: {generatedAt}").FontColor("#777777");
                        });
                    });
                    header.Item().PaddingTop(6).LineHorizontal(1).LineColor("#1A5276");
                });

                page.Content().PaddingVertical(10).Column(content =>
                {
                    content.Spacing(14);

                    content.Item().Column(c =>
                    {
                        c.Item().Text(labels.TopSlots).Bold().FontSize(13);
                        c.Item().PaddingTop(4).Table(table =>
                        {
                            table.ColumnsDefinition(cols =>
                            {
                                cols.RelativeColumn(2);
                                cols.RelativeColumn(2);
                            });
                            table.Header(h =>
                            {
                                HeaderCell(h.Cell(), labels.TimeSlot);
                                HeaderCell(h.Cell(), labels.BookingCount);
                            });
                            foreach (var slot in topSlots)
                            {
                                BodyCell(table.Cell(), $"{slot.Start:HH\\:mm} – {slot.Start.AddHours(1):HH\\:mm}");
                                BodyCell(table.Cell(), slot.Count.ToString());
                            }
                            if (topSlots.Count == 0)
                                table.Cell().ColumnSpan(2).Element(e => e.Padding(4)).Text(labels.NoDataForPeriod).Italic();
                        });
                    });

                    content.Item().Column(c =>
                    {
                        c.Item().Text(labels.OccupancyByCourt).Bold().FontSize(13);
                        c.Item().PaddingTop(4).Table(table =>
                        {
                            table.ColumnsDefinition(cols =>
                            {
                                cols.RelativeColumn(3);
                                cols.RelativeColumn(3);
                                cols.RelativeColumn(2);
                                cols.RelativeColumn(2);
                                cols.RelativeColumn(2);
                                cols.RelativeColumn(2);
                            });
                            table.Header(h =>
                            {
                                HeaderCell(h.Cell(), labels.Court);
                                HeaderCell(h.Cell(), labels.Centre);
                                HeaderCell(h.Cell(), labels.BookingCount);
                                HeaderCell(h.Cell(), labels.ReservedHours);
                                HeaderCell(h.Cell(), labels.AvailableHours);
                                HeaderCell(h.Cell(), labels.OccupancyPercent);
                            });
                            foreach (var row in occupancyRows)
                            {
                                BodyCell(table.Cell(), row.Name);
                                BodyCell(table.Cell(), row.Center);
                                BodyCell(table.Cell(), row.Count.ToString());
                                BodyCell(table.Cell(), $"{row.Reserved:0.#}");
                                BodyCell(table.Cell(), $"{row.Available:0.#}");
                                BodyCell(table.Cell(), $"{row.Occupancy:P0}");
                            }
                            if (occupancyRows.Count == 0)
                                table.Cell().ColumnSpan(6).Element(e => e.Padding(4)).Text(labels.NoDataForPeriod).Italic();
                        });
                    });
                });

                page.Footer().AlignCenter().Text(text =>
                {
                    text.Span(labels.Page);
                    text.CurrentPageNumber();
                    text.Span(" / ");
                    text.TotalPages();
                });
            });
        });

        return document.GeneratePdf();
    }

    private static void HeaderCell(IContainer cell, string text) =>
        cell.Background("#1A5276").Padding(5).Text(text).FontColor("#FFFFFF").Bold().FontSize(9);

    private static void BodyCell(IContainer cell, string text) =>
        cell.BorderBottom(1).BorderColor("#E5E7E9").Padding(4).Text(text).FontSize(9);
}
