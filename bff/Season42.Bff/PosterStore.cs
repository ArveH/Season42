using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// The poster bytes on disk, one file per series and named after the series' id, filling itself
/// from TMDB as posters are asked for. Nothing here expires, for the same reason nothing in the
/// <see cref="LogoStore"/> beside it does; the key is the difference between the two (ADR-0012).
/// </summary>
/// <remarks>
/// Keyed on the id rather than on the path TMDB published, because there is no snapshot of
/// posters to resolve an id against: keyed on the path, every hit would first have to spend a
/// details call working out what the path was, and the store would save nothing. Keyed on the id,
/// a hit costs no TMDB call at all and only a miss pays details-then-image.
/// </remarks>
public sealed class PosterStore
{
    /// <summary>The poster bytes sit beside the snapshot and the logos, not among them.</summary>
    public const string DirectoryName = "posters";

    /// <summary>
    /// What a poster is served as. TMDB publishes posters as JPEG — unlike provider logos, which
    /// come in two formats and so have to be read off the path they were published under.
    /// </summary>
    public const string ContentType = "image/jpeg";

    private readonly string _directory;
    private readonly IServiceProvider _services;
    private readonly ILogger<PosterStore> _log;

    // One gate per series, so that two asks for the same missing poster cost one fetch rather
    // than two. Unlike the logo store's, these are reclaimed the moment nobody is holding one:
    // the ids are whatever a caller sends, so a dictionary that only ever grew would be a way to
    // spend this server's memory by asking about ids that do not exist.
    private readonly Dictionary<int, Gate> _fetching = new();

    public PosterStore(
        IOptions<TmdbOptions> options,
        IHostEnvironment environment,
        IServiceProvider services,
        ILogger<PosterStore> log)
    {
        _services = services;
        _log = log;
        _directory = Path.Combine(options.Value.StoreRootFrom(environment), DirectoryName);
    }

    /// <summary>What one series' poster is called in the store: its id, and nothing of TMDB's.</summary>
    public static string FileNameOf(int id) => $"{id}.jpg";

    /// <summary>
    /// The bytes of one series' poster, from the store if it is there and from TMDB if it is
    /// not, or null where there is no poster to be had — TMDB listing none for the series, and
    /// TMDB having never heard of the id, are the same answer to whoever asked.
    /// </summary>
    /// <remarks>
    /// A null is not remembered. A poster is asked for about twice per adoption rather than once
    /// per render, so a negative kept here would save almost nothing and would go on being wrong
    /// about a series that has since gained a poster.
    /// </remarks>
    /// <exception cref="HttpRequestException">TMDB could not be asked, or refused.</exception>
    /// <exception cref="JsonException">TMDB answered with something that is not a series.</exception>
    public async Task<byte[]?> ReadOrFetchAsync(int id, CancellationToken cancellationToken)
    {
        var path = Path.Combine(_directory, FileNameOf(id));
        if (File.Exists(path)) return await File.ReadAllBytesAsync(path, cancellationToken);

        var gate = Enter(id);
        await gate.Waiting.WaitAsync(cancellationToken);
        try
        {
            // Whoever held the gate may have been fetching this very poster.
            if (File.Exists(path)) return await File.ReadAllBytesAsync(path, cancellationToken);

            // Resolved per fetch rather than held: both of these reach TMDB through a typed
            // HttpClient, and a singleton holding one would pin a single handler for the life of
            // the server.
            using var scope = _services.CreateScope();
            var details = scope.ServiceProvider.GetRequiredService<TmdbSeriesDetails>();

            // The cost of a miss: the details that say where the poster is, then the poster.
            var posterPath = await details.PosterPathOfAsync(id, cancellationToken);
            if (posterPath is null) return null;

            var images = scope.ServiceProvider.GetRequiredService<TmdbImages>();
            var bytes = await images.FetchPosterAsync(posterPath, cancellationToken);

            await StoreFile.WriteAsync(path, bytes, _log, cancellationToken);
            return bytes;
        }
        finally
        {
            gate.Waiting.Release();
            Leave(id);
        }
    }

    /// <summary>One series' gate, taken out for as long as anyone is waiting on it.</summary>
    private sealed class Gate
    {
        public SemaphoreSlim Waiting { get; } = new(1, 1);

        /// <summary>How many asks are holding or waiting on it, under the dictionary's lock.</summary>
        public int Holders { get; set; }
    }

    private Gate Enter(int id)
    {
        lock (_fetching)
        {
            if (!_fetching.TryGetValue(id, out var gate)) _fetching[id] = gate = new Gate();
            gate.Holders++;
            return gate;
        }
    }

    private void Leave(int id)
    {
        lock (_fetching)
        {
            if (!_fetching.TryGetValue(id, out var gate)) return;
            if (--gate.Holders == 0) _fetching.Remove(id);
        }
    }

}
