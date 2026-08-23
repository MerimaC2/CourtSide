using CourtSide.Core.Enumerations;
using CourtSide.Core.Helpers;
using CourtSide.Infrastructure;
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
}

/// <summary>Generates PDF reports with QuestPDF.</summary>
public class ReportService : IReportService
{
    static ReportService() => QuestPDF.Settings.License = LicenseType.Community;

    private readonly DatabaseContext _db;

    public ReportService(DatabaseContext db) => _db = db;

    public async Task<byte[]> ReservationsPdfAsync(DateOnly? dateFrom, DateOnly? dateTo, int? sportCenterId,
        string? language = null)
    {
        var labels = ReportLabels.For(language);

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

        var periodText = $"{(dateFrom.HasValue ? dateFrom.Value.ToString("dd.MM.yyyy") : labels.PeriodStart)}" +
                         $" – {(dateTo.HasValue ? dateTo.Value.ToString("dd.MM.yyyy") : labels.PeriodEnd)}";
        var generatedAt = DateTime.UtcNow.ToString("dd.MM.yyyy HH:mm 'UTC'");

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

    private static void HeaderCell(IContainer cell, string text) =>
        cell.Background("#1A5276").Padding(5).Text(text).FontColor("#FFFFFF").Bold().FontSize(9);

    private static void BodyCell(IContainer cell, string text) =>
        cell.BorderBottom(1).BorderColor("#E5E7E9").Padding(4).Text(text).FontSize(9);
}
