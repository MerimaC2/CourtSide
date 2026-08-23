using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CourtSide.Services.Services;

/// <summary>
/// Closes out reservations once their slot has passed: a booking moves from Confirmed to
/// Completed with the passage of time rather than through a user action, so the sweep runs
/// on a schedule. The transition rules and notifications live in <see cref="ReservationService"/>;
/// this only decides when to run them.
/// </summary>
public class ReservationCompletionService : BackgroundService
{
    private static readonly TimeSpan SweepInterval = TimeSpan.FromMinutes(5);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ReservationCompletionService> _logger;

    public ReservationCompletionService(IServiceScopeFactory scopeFactory,
        ILogger<ReservationCompletionService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await SweepOnceAsync(stoppingToken);

            try
            {
                await Task.Delay(SweepInterval, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }

    private async Task SweepOnceAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var reservations = scope.ServiceProvider.GetRequiredService<IReservationService>();
            var completed = await reservations.CompletePastDueAsync(cancellationToken);
            if (completed > 0)
                _logger.LogInformation("Završeno {Count} rezervacija kojima je termin istekao.", completed);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Greška pri zatvaranju isteklih rezervacija.");
        }
    }
}
