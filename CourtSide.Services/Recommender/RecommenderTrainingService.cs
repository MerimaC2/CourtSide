using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CourtSide.Services.Recommender;

/// <summary>
/// Background job that keeps the recommender model fresh: warm-loads any persisted model on startup,
/// trains once at boot, then periodically re-trains from the latest history (see recommender-dokumentacija.md).
/// </summary>
public class RecommenderTrainingService : BackgroundService
{
    private static readonly TimeSpan RetrainInterval = TimeSpan.FromHours(6);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IRecommenderModel _model;
    private readonly ILogger<RecommenderTrainingService> _logger;

    public RecommenderTrainingService(IServiceScopeFactory scopeFactory, IRecommenderModel model,
        ILogger<RecommenderTrainingService> logger)
    {
        _scopeFactory = scopeFactory;
        _model = model;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Warm start: restore the last persisted model so recommendations work before the first re-train finishes.
        try
        {
            if (_model.TryLoad(RecommenderService.ModelPath))
                _logger.LogInformation("Recommender: učitan sačuvani model s diska (warm start).");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Recommender: nije uspjelo učitavanje sačuvanog modela — slijedi treniranje od nule.");
        }

        while (!stoppingToken.IsCancellationRequested)
        {
            await TrainOnceAsync(stoppingToken);

            try
            {
                await Task.Delay(RetrainInterval, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }

    private async Task TrainOnceAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var recommender = scope.ServiceProvider.GetRequiredService<IRecommenderService>();
            await recommender.TrainAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Recommender: greška tokom treniranja modela.");
        }
    }
}
