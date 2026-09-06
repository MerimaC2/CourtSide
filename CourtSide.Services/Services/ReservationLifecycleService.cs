using CourtSide.Shared.Models;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CourtSide.Services.Services;

/// <summary>
/// Moves reservations along as time passes rather than as users act: a confirmed booking whose
/// slot has ended becomes Completed, and one nobody confirmed before its slot began is cancelled
/// so it stops holding the slot. The rules and notifications live in <see cref="ReservationService"/>;
/// this only decides when to run them.
/// </summary>
public class ReservationLifecycleService : BackgroundService
{
    private readonly TimeSpan _sweepInterval;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ReservationLifecycleService> _logger;

    public ReservationLifecycleService(IServiceScopeFactory scopeFactory,
        IOptions<TimeSettings> options, ILogger<ReservationLifecycleService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _sweepInterval = TimeSpan.FromMinutes(Math.Clamp(options.Value.SweepIntervalMinutes, 1, 60));
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await SweepOnceAsync(stoppingToken);

            try
            {
                await Task.Delay(_sweepInterval, stoppingToken);
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
            var (completed, expired) = await reservations.ProcessPastDueAsync(cancellationToken);
            if (completed > 0 || expired > 0)
                _logger.LogInformation(
                    "Obrada isteklih rezervacija: završeno {Completed}, otkazano nepotvrđenih {Expired}.",
                    completed, expired);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Greška pri obradi isteklih rezervacija.");
        }
    }
}
