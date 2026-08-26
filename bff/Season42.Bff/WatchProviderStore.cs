using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// Holds the last good snapshot of Watch Providers and answers searches from it. The snapshot
/// lives in memory and on disk: a restart reads the file back rather than waiting on TMDB, and a
/// refresh that fails leaves what is already here alone.
/// </summary>
public sealed class WatchProviderStore
{
    /// <summary>How many matches a single search can return.</summary>
    public const int MaxResults = 20;

    private static readonly JsonSerializerOptions SnapshotFormat = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
    };

    private readonly string _snapshotPath;
    private readonly ILogger<WatchProviderStore> _log;
    private volatile IReadOnlyList<WatchProvider>? _providers;

    public WatchProviderStore(
        IOptions<TmdbOptions> options, IHostEnvironment environment, ILogger<WatchProviderStore> log)
    {
        _log = log;
        _snapshotPath = Path.Combine(
            Path.GetFullPath(options.Value.LogoStorePath, environment.ContentRootPath),
            TmdbOptions.SnapshotFileName);
        _providers = ReadFromDisk();
    }

    /// <summary>
    /// The Watch Providers whose names contain <paramref name="search"/>, most prominent first and
    /// capped at <see cref="MaxResults"/>. Null — as distinct from empty — means no snapshot has
    /// ever been taken, so the answer is unknown rather than "nothing matched".
    /// </summary>
    public IReadOnlyList<WatchProvider>? Search(string search)
    {
        var providers = _providers;
        if (providers is null) return null;

        return providers
            .Where(provider => provider.Name.Contains(search, StringComparison.OrdinalIgnoreCase))
            .OrderBy(provider => provider.DisplayPriority)
            .ThenBy(provider => provider.Name, StringComparer.OrdinalIgnoreCase)
            .Take(MaxResults)
            .ToList();
    }

    /// <summary>
    /// Whether the current snapshot names <paramref name="logoFile"/> as some Watch Provider's
    /// logo. This is the allowlist the logo route serves from: a path that is not in it is not a
    /// path this server has ever published, whatever it looks like.
    /// </summary>
    public bool Knows(string logoFile)
    {
        var providers = _providers;
        if (providers is null) return false;

        // TMDB's logo paths carry a leading slash; the route's are what follows it.
        return providers.Any(provider =>
            string.Equals(provider.LogoPath, $"/{logoFile}", StringComparison.Ordinal));
    }

    /// <summary>Takes a fresh snapshot, in memory and on disk. Only a successful fetch gets here.</summary>
    public async Task UpdateAsync(IReadOnlyList<WatchProvider> providers, CancellationToken cancellationToken)
    {
        _providers = providers;

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_snapshotPath)!);
            await using var file = File.Create(_snapshotPath);
            await JsonSerializer.SerializeAsync(file, providers, SnapshotFormat, cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // The snapshot in memory is the one that serves searches; the file only shortens the
            // next start. Losing it is worth a warning, not a failed refresh.
            _log.LogWarning(exception, "Could not write the watch provider snapshot to {Path}.", _snapshotPath);
        }
    }

    private IReadOnlyList<WatchProvider>? ReadFromDisk()
    {
        if (!File.Exists(_snapshotPath)) return null;

        try
        {
            using var file = File.OpenRead(_snapshotPath);
            // An empty list that parsed is still a snapshot: "TMDB knows of none" and "nothing has
            // been fetched yet" are different answers, and only the second is a 503.
            var providers = JsonSerializer.Deserialize<List<WatchProvider>>(file, SnapshotFormat);
            if (providers is null) return null;

            _log.LogInformation(
                "Read {Count} watch providers from the snapshot at {Path}.", providers.Count, _snapshotPath);
            return providers;
        }
        catch (Exception exception)
        {
            _log.LogWarning(exception, "Could not read the watch provider snapshot at {Path}.", _snapshotPath);
            return null;
        }
    }
}
