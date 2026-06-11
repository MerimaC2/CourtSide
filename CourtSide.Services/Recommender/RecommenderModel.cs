using Microsoft.ML;
using Microsoft.ML.Data;

namespace CourtSide.Services.Recommender;

/// <summary>One implicit user↔court interaction row fed to the matrix-factorization trainer.</summary>
public class CourtInteraction
{
    public float UserId { get; set; }
    public float CourtId { get; set; }
    public float Label { get; set; } = 1f; // one-class: every observed interaction is a positive signal
}

/// <summary>Scoring output column produced by the trained model.</summary>
public class CourtScorePrediction
{
    public float Score { get; set; }
}

/// <summary>
/// Singleton in-memory cache of the trained recommender model. Holds the shared <see cref="MLContext"/>,
/// the current <see cref="ITransformer"/> and the set of user/court ids the model actually knows, and
/// handles scoring plus file persistence. Thread-safe: the background trainer swaps the model while
/// API requests score against it.
/// </summary>
public interface IRecommenderModel
{
    MLContext Context { get; }
    bool IsTrained { get; }
    bool KnowsUser(int userId);

    void Update(ITransformer model, DataViewSchema schema, IEnumerable<int> userIds, IEnumerable<int> courtIds);

    /// <summary>Scores the given courts for the user. Returns courtId→score for known (user, court) pairs only.</summary>
    IReadOnlyDictionary<int, double> Score(int userId, IEnumerable<int> courtIds);

    void Save(string path);
    bool TryLoad(string path);
}

public class RecommenderModel : IRecommenderModel
{
    private readonly object _gate = new();
    private readonly MLContext _ml = new(seed: 0);

    private ITransformer? _model;
    private DataViewSchema? _schema;
    private HashSet<int> _users = new();
    private HashSet<int> _courts = new();

    public MLContext Context => _ml;

    public bool IsTrained
    {
        get { lock (_gate) return _model is not null; }
    }

    public bool KnowsUser(int userId)
    {
        lock (_gate) return _users.Contains(userId);
    }

    public void Update(ITransformer model, DataViewSchema schema, IEnumerable<int> userIds, IEnumerable<int> courtIds)
    {
        var users = new HashSet<int>(userIds);
        var courts = new HashSet<int>(courtIds);
        lock (_gate)
        {
            _model = model;
            _schema = schema;
            _users = users;
            _courts = courts;
        }
    }

    public IReadOnlyDictionary<int, double> Score(int userId, IEnumerable<int> courtIds)
    {
        ITransformer model;
        HashSet<int> users, courts;
        lock (_gate)
        {
            if (_model is null) return new Dictionary<int, double>();
            model = _model;
            users = _users;
            courts = _courts;
        }

        if (!users.Contains(userId)) return new Dictionary<int, double>();

        // Only score courts the model has seen; unseen ids map to a missing key and yield NaN.
        var candidates = courtIds
            .Where(courts.Contains)
            .Distinct()
            .Select(c => new CourtInteraction { UserId = userId, CourtId = c, Label = 0f })
            .ToList();

        if (candidates.Count == 0) return new Dictionary<int, double>();

        var input = _ml.Data.LoadFromEnumerable(candidates);
        var scored = model.Transform(input);
        var predictions = _ml.Data.CreateEnumerable<CourtScorePrediction>(scored, reuseRowObject: false).ToList();

        var result = new Dictionary<int, double>(candidates.Count);
        for (var i = 0; i < candidates.Count; i++)
        {
            var score = predictions[i].Score;
            if (float.IsNaN(score) || float.IsInfinity(score)) continue;
            result[(int)candidates[i].CourtId] = score;
        }
        return result;
    }

    public void Save(string path)
    {
        ITransformer? model;
        DataViewSchema? schema;
        int[] users, courts;
        lock (_gate)
        {
            model = _model;
            schema = _schema;
            users = _users.ToArray();
            courts = _courts.ToArray();
        }
        if (model is null || schema is null) return;

        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        _ml.Model.Save(model, schema, path);
        // Sidecar with the known ids, so a cold start can restore a fully usable cache from disk.
        File.WriteAllText(SidecarPath(path),
            string.Join('\n', string.Join(',', users), string.Join(',', courts)));
    }

    public bool TryLoad(string path)
    {
        if (!File.Exists(path) || !File.Exists(SidecarPath(path))) return false;

        var model = _ml.Model.Load(path, out var schema);
        var lines = File.ReadAllLines(SidecarPath(path));
        var users = ParseIds(lines.ElementAtOrDefault(0));
        var courts = ParseIds(lines.ElementAtOrDefault(1));
        Update(model, schema, users, courts);
        return true;
    }

    private static string SidecarPath(string path) => path + ".ids";

    private static IEnumerable<int> ParseIds(string? line) =>
        string.IsNullOrWhiteSpace(line)
            ? Enumerable.Empty<int>()
            : line.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(int.Parse);
}
