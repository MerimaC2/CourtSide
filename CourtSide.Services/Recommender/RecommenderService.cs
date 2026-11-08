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

    /// <summary>
    /// How much each signal counts. One-class matrix factorization reads every observed cell as
    /// the same positive value, so strength cannot be carried in the label — it is expressed by
    /// how many times a (user, court) pair is fed to the trainer. Opening a court's details says
    /// far less than booking it, and the cap keeps repeated browsing of the same court from ever
    /// adding up to a booking.
    /// </summary>
    private const int ReservationUnits = 5;
    private const int ViewUnits = 1;
    private const int MaxViewUnitsPerPair = 3;

    /// <summary>Ceiling per pair, so one very active user cannot dominate the whole matrix.</summary>
    private const int MaxUnitsPerPair = 50;

    private const string ReasonCollaborative = "Korisnici sa sličnim rezervacijama često biraju ovaj teren.";
    // Only the single busiest court of the period is called the most popular; any other court
    // the fallback offers on popularity alone is merely popular.
    private const string ReasonMostPopular = "Najpopularniji teren u zadnjih 30 dana.";
    private const string ReasonPopular = "Popularan teren u zadnjih 30 dana.";
    // The wording names only what actually matched, so a court chosen for its city alone is
    // not described as matching the user's sport too.
    private const string ReasonAffinitySportAndCity = "Popularan teren u sportu i gradu koje inače birate.";
    private const string ReasonAffinitySport = "Popularan teren u sportu koji inače birate.";
    private const string ReasonAffinityCity = "Popularan teren u gradu u kojem inače igrate.";
    private const string ReasonGeneric = "Predloženo za tebe.";
    private const string ReasonFavourite = "Često rezervišete ovaj teren.";

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

        // The user's own booking history: what they have already played on, and which sport and
        // city they keep coming back to.
        var history = await _db.Reservations
            .Where(r => r.ClientId == userId && r.Status != ReservationStatus.Cancelled)
            .Select(r => new { r.CourtId, r.Court.SportId, r.Court.SportCenter.CityId })
            .ToListAsync();

        var reservedSet = history.Select(h => h.CourtId).ToHashSet();
        var bookingsPerCourt = history.GroupBy(h => h.CourtId).ToDictionary(g => g.Key, g => g.Count());
        var sportAffinity = history.GroupBy(h => h.SportId).ToDictionary(g => g.Key, g => g.Count());
        var cityAffinity = history.GroupBy(h => h.CityId).ToDictionary(g => g.Key, g => g.Count());

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

        var traits = await _db.Courts
            .Where(c => c.IsActive)
            .Select(c => new { c.Id, c.SportId, c.SportCenter.CityId })
            .ToDictionaryAsync(c => c.Id, c => (c.SportId, c.CityId));

        // How well a court matches what this user usually books. Used to order the fallbacks, so
        // a suggestion is not merely popular in general but plausible for this person.
        int Affinity(int courtId)
        {
            if (!traits.TryGetValue(courtId, out var trait)) return 0;
            return sportAffinity.GetValueOrDefault(trait.SportId) + cityAffinity.GetValueOrDefault(trait.CityId);
        }

        // Why a popular court was placed where it was: the part of the user's habits it matches,
        // or otherwise its popularity alone.
        string PopularReason(int courtId, bool isMostPopular)
        {
            var popularity = isMostPopular ? ReasonMostPopular : ReasonPopular;
            if (!traits.TryGetValue(courtId, out var trait)) return popularity;
            var sameSport = sportAffinity.ContainsKey(trait.SportId);
            var sameCity = cityAffinity.ContainsKey(trait.CityId);
            return (sameSport, sameCity) switch
            {
                (true, true) => ReasonAffinitySportAndCity,
                (true, false) => ReasonAffinitySport,
                (false, true) => ReasonAffinityCity,
                _ => popularity
            };
        }

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

        // 2) Fallback — popular in the last 30 days, but read through what this user plays and
        //    where: courts in their sport and city come first, and only then the busiest ones.
        if (result.Count < count)
        {
            var since = DateTime.UtcNow.AddDays(-30);
            var popular = await _db.Reservations
                .Where(r => r.Status != ReservationStatus.Cancelled && r.CreatedAt >= since)
                .GroupBy(r => r.CourtId)
                .Select(g => new { CourtId = g.Key, Count = g.Count() })
                .ToListAsync();

            // The busiest active court of the period, whether or not it ends up in this list — a
            // court the user already booked still outranks the ones offered in its place.
            var mostPopularId = popular
                .Where(p => byId.ContainsKey(p.CourtId))
                .OrderByDescending(p => p.Count)
                .ThenBy(p => p.CourtId)
                .Select(p => (int?)p.CourtId)
                .FirstOrDefault();

            foreach (var p in popular
                .OrderByDescending(x => Affinity(x.CourtId))
                .ThenByDescending(x => x.Count)
                .ThenBy(x => x.CourtId))
            {
                if (result.Count >= count) break;
                if (reservedSet.Contains(p.CourtId) || used.Contains(p.CourtId)) continue;
                if (!byId.TryGetValue(p.CourtId, out var dto)) continue;
                dto.Score = 0;
                // Only the busiest court is labelled the most popular; one picked ahead of busier
                // courts for matching the user's habits gets the regular popular wording.
                dto.Reason = PopularReason(p.CourtId, p.CourtId == mostPopularId);
                used.Add(p.CourtId);
                result.Add(dto);
            }
        }

        // 3) Any other active court, closest match first (handles a database with no history yet).
        if (result.Count < count)
        {
            foreach (var dto in byId.Values.OrderByDescending(c => Affinity(c.CourtId)))
            {
                if (result.Count >= count) break;
                if (reservedSet.Contains(dto.CourtId) || used.Contains(dto.CourtId)) continue;
                dto.Score = 0;
                dto.Reason = ReasonGeneric;
                used.Add(dto.CourtId);
                result.Add(dto);
            }
        }

        // 4) Only when nothing new is left: a regular who has played on every court is offered
        //    their own favourites, the most useful way back to booking one again. A court the
        //    user has already booked never displaces one they have not.
        if (result.Count == 0)
        {
            foreach (var courtId in bookingsPerCourt.OrderByDescending(b => b.Value).Select(b => b.Key))
            {
                if (result.Count >= count) break;
                if (used.Contains(courtId) || !byId.TryGetValue(courtId, out var dto)) continue;
                dto.Score = 0;
                dto.Reason = ReasonFavourite;
                used.Add(courtId);
                result.Add(dto);
            }
        }

        return result;
    }

    public async Task TrainAsync(CancellationToken cancellationToken = default)
    {
        // Signals for the same user and court are counted up first, so that how strongly a court
        // is preferred can be turned into how many times the pair enters the matrix.
        var units = new Dictionary<(int UserId, int CourtId), int>();

        // Primary signal: reservations (a booking is a strong interest signal).
        var reservationPairs = await _db.Reservations
            .Where(r => r.Status != ReservationStatus.Cancelled)
            .Select(r => new { r.ClientId, r.CourtId })
            .ToListAsync(cancellationToken);
        foreach (var p in reservationPairs)
        {
            var key = (p.ClientId, p.CourtId);
            units[key] = units.GetValueOrDefault(key) + ReservationUnits;
        }

        // Secondary signal: court detail views (browsing history), capped per court so that
        // browsing can never reach what a single booking is worth.
        var viewCounts = await _db.CourtViewLogs
            .GroupBy(v => new { v.UserId, v.CourtId })
            .Select(g => new { g.Key.UserId, g.Key.CourtId, Count = g.Count() })
            .ToListAsync(cancellationToken);
        foreach (var v in viewCounts)
        {
            var key = (v.UserId, v.CourtId);
            units[key] = units.GetValueOrDefault(key) +
                Math.Min(v.Count * ViewUnits, MaxViewUnitsPerPair);
        }

        var interactions = new List<CourtInteraction>();
        foreach (var (key, count) in units)
        {
            for (var i = 0; i < Math.Min(count, MaxUnitsPerPair); i++)
            {
                interactions.Add(new CourtInteraction { UserId = key.UserId, CourtId = key.CourtId });
            }
        }

        var users = interactions.Select(i => (int)i.UserId).Distinct().ToList();
        var courts = interactions.Select(i => (int)i.CourtId).Distinct().ToList();

        if (units.Count < MinInteractions || users.Count < MinDistinctUsers || courts.Count < MinDistinctCourts)
        {
            _logger.LogInformation(
                "Recommender: nedovoljno podataka za treniranje ({Pairs} parova, {Users} korisnika, {Courts} terena) — koristi se popularnost (fallback).",
                units.Count, users.Count, courts.Count);
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
            "Recommender: model istreniran na {Pairs} parova / {Interactions} jedinica signala ({Users} korisnika, {Courts} terena).",
            units.Count, interactions.Count, users.Count, courts.Count);
    }
}
