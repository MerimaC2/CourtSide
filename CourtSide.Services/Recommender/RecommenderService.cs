using CourtSide.Core.Dto;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Infrastructure;
using CourtSide.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.ML;
using Microsoft.ML.Trainers;

namespace CourtSide.Services.Recommender;

public interface IRecommenderService
{
    /// <summary>Top recommendations for the currently authenticated user (collaborative filtering + fallback).</summary>
    Task<List<RecommendationDto>> GetForCurrentUserAsync(int count = 3);

    /// <summary>(Re)trains the matrix-factorization model from real history and refreshes the in-memory cache.</summary>
    Task TrainAsync(CancellationToken cancellationToken = default);
}

/// <summary>
/// Collaborative-filtering recommender (ML.NET Matrix Factorization, one-class/implicit) over real usage
/// signals — reservations (primary) and court views (secondary). Falls back to 30-day popularity on cold start.
/// Implementation follows <c>recommender-dokumentacija.md</c>.
/// </summary>
public class RecommenderService : IRecommenderService
{
    // Below these thresholds the interaction matrix is too sparse for MF — use popularity fallback only.
    private const int MinInteractions = 6;
    private const int MinDistinctUsers = 2;
    private const int MinDistinctCourts = 2;

    private const string ReasonCollaborative = "Korisnici sa sličnim rezervacijama često biraju ovaj teren.";
    private const string ReasonPopular = "Najpopularniji teren u zadnjih 30 dana.";
    private const string ReasonGeneric = "Predloženo za tebe.";

    /// <summary>On-disk location of the persisted model (and its id sidecar).</summary>
    public static readonly string ModelPath =
        Path.Combine(AppContext.BaseDirectory, "models", "recommender.zip");

    private readonly DatabaseContext _db;
    private readonly ICurrentUser _currentUser;
    private readonly IRecommenderModel _model;
    private readonly ILogger<RecommenderService> _logger;

    public RecommenderService(DatabaseContext db, ICurrentUser currentUser,
        IRecommenderModel model, ILogger<RecommenderService> logger)
    {
        _db = db;
        _currentUser = currentUser;
        _model = model;
        _logger = logger;
    }

    public async Task<List<RecommendationDto>> GetForCurrentUserAsync(int count = 3)
    {
        var userId = _currentUser.UserId ?? throw new BusinessException("Niste prijavljeni.");
        count = Math.Clamp(count, 1, 10);

        // Candidate pool: active courts the user has not already reserved.
        var reserved = await _db.Reservations
            .Where(r => r.ClientId == userId && r.Status != ReservationStatus.Cancelled)
            .Select(r => r.CourtId)
            .Distinct()
            .ToListAsync();
        var reservedSet = reserved.ToHashSet();

        var byId = await _db.Courts
            .Where(c => c.IsActive)
            .Select(c => new RecommendationDto
            {
                CourtId = c.Id,
                CourtName = c.Name,
                SportName = c.Sport.Name,
                SportCenterName = c.SportCenter.Name,
                PricePerHour = c.PricePerHour,
                PrimaryImageId = c.Images.Where(i => i.IsPrimary).Select(i => (int?)i.Id).FirstOrDefault()
            })
            .ToDictionaryAsync(c => c.CourtId);

        var candidateIds = byId.Keys.Where(id => !reservedSet.Contains(id)).ToList();

        var result = new List<RecommendationDto>();
        var used = new HashSet<int>();

        // 1) Collaborative filtering (only if the model knows this user).
        if (_model.IsTrained && _model.KnowsUser(userId))
        {
            var scores = _model.Score(userId, candidateIds);
            foreach (var (courtId, score) in scores.OrderByDescending(s => s.Value).Take(count))
            {
                if (!byId.TryGetValue(courtId, out var dto) || !used.Add(courtId)) continue;
                dto.Score = Math.Round(score, 4);
                dto.Reason = ReasonCollaborative;
                result.Add(dto);
            }
        }

        // 2) Fallback — most popular courts in the last 30 days (by reservations made).
        if (result.Count < count)
        {
            var since = DateTime.UtcNow.AddDays(-30);
            var popular = await _db.Reservations
                .Where(r => r.Status != ReservationStatus.Cancelled && r.CreatedAt >= since)
                .GroupBy(r => r.CourtId)
                .Select(g => new { CourtId = g.Key, Count = g.Count() })
                .OrderByDescending(x => x.Count)
                .ToListAsync();

            foreach (var p in popular)
            {
                if (result.Count >= count) break;
                if (reservedSet.Contains(p.CourtId) || used.Contains(p.CourtId)) continue;
                if (!byId.TryGetValue(p.CourtId, out var dto)) continue;
                dto.Score = 0;
                dto.Reason = ReasonPopular;
                used.Add(p.CourtId);
                result.Add(dto);
            }
        }

        // 3) Last resort — any other active court (handles a cold database with no history yet).
        if (result.Count < count)
        {
            foreach (var dto in byId.Values)
            {
                if (result.Count >= count) break;
                if (reservedSet.Contains(dto.CourtId) || used.Contains(dto.CourtId)) continue;
                dto.Score = 0;
                dto.Reason = ReasonGeneric;
                used.Add(dto.CourtId);
                result.Add(dto);
            }
        }

        return result;
    }

    public async Task TrainAsync(CancellationToken cancellationToken = default)
    {
        var interactions = new List<CourtInteraction>();

        // Primary signal: reservations (a booking is a strong interest signal).
        var reservationPairs = await _db.Reservations
            .Where(r => r.Status != ReservationStatus.Cancelled)
            .Select(r => new { r.ClientId, r.CourtId })
            .ToListAsync(cancellationToken);
        foreach (var p in reservationPairs)
            interactions.Add(new CourtInteraction { UserId = p.ClientId, CourtId = p.CourtId });

        // Secondary signal: court detail views (browsing history).
        var viewPairs = await _db.CourtViewLogs
            .Select(v => new { v.UserId, v.CourtId })
            .ToListAsync(cancellationToken);
        foreach (var p in viewPairs)
            interactions.Add(new CourtInteraction { UserId = p.UserId, CourtId = p.CourtId });

        var users = interactions.Select(i => (int)i.UserId).Distinct().ToList();
        var courts = interactions.Select(i => (int)i.CourtId).Distinct().ToList();

        if (interactions.Count < MinInteractions || users.Count < MinDistinctUsers || courts.Count < MinDistinctCourts)
        {
            _logger.LogInformation(
                "Recommender: nedovoljno podataka za treniranje ({Interactions} interakcija, {Users} korisnika, {Courts} terena) — koristi se popularnost (fallback).",
                interactions.Count, users.Count, courts.Count);
            return;
        }

        var ml = _model.Context;
        var data = ml.Data.LoadFromEnumerable(interactions);

        var options = new MatrixFactorizationTrainer.Options
        {
            MatrixColumnIndexColumnName = "UserIdKey",
            MatrixRowIndexColumnName = "CourtIdKey",
            LabelColumnName = nameof(CourtInteraction.Label),
            LossFunction = MatrixFactorizationTrainer.LossFunctionType.SquareLossOneClass,
            Alpha = 0.01,
            Lambda = 0.025,
            ApproximationRank = 32,
            NumberOfIterations = 100,
            C = 0.00001,
            Quiet = true
        };

        var pipeline = ml.Transforms.Conversion
                .MapValueToKey("UserIdKey", nameof(CourtInteraction.UserId))
            .Append(ml.Transforms.Conversion
                .MapValueToKey("CourtIdKey", nameof(CourtInteraction.CourtId)))
            .Append(ml.Recommendation().Trainers.MatrixFactorization(options));

        var model = pipeline.Fit(data);
        _model.Update(model, data.Schema, users, courts);

        try
        {
            _model.Save(ModelPath);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Recommender: model istreniran ali nije sačuvan na disk ({Path}).", ModelPath);
        }

        _logger.LogInformation(
            "Recommender: model istreniran na {Interactions} interakcija ({Users} korisnika, {Courts} terena).",
            interactions.Count, users.Count, courts.Count);
    }
}
