using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>Which kind of thing a poster belongs to, and so whose id it is keyed under.</summary>
/// <remarks>
/// TMDB numbers its series and its movies apart, so the id alone does not say what a poster is a
/// poster of: 550 is a series to one half of TMDB's API and a movie to the other. Two keyspaces,
/// one store, and the subject is what keeps them from meeting.
/// </remarks>
public enum PosterSubject
{
    Series,
    Movie,
}

/// <summary>
/// The poster bytes on disk, one file per Library Entry and named after that entry's id, filling
/// itself from TMDB as posters are asked for. Nothing here is kept past
/// <see cref="TmdbOptions.ImageLifetime"/>, which is the same limit the <see cref="LogoStore"/>
/// beside it keeps to (ADR-0020); the key is the difference between the two (ADR-0012).
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
    private readonly TimeSpan _lifetime;
    private readonly IServiceProvider _services;
    private readonly ILogger<PosterStore> _log;

    // One gate per poster, so that two asks for the same missing one cost one fetch rather than
    // two. Keyed on the subject as well as the id, because the two keyspaces are TMDB's own and a
    // series and a movie may share a number. Unlike the logo store's, these are reclaimed the
    // moment nobody is holding one: the ids are whatever a caller sends, so a dictionary that only
    // ever grew would be a way to spend this server's memory by asking about ids that do not exist.
    private readonly Dictionary<(PosterSubject Subject, int Id), Gate> _fetching = new();

    public PosterStore(
        IOptions<TmdbOptions> options,
        IHostEnvironment environment,
        IServiceProvider services,
        ILogger<PosterStore> log)
    {
        _services = services;
        _log = log;
        _directory = Path.Combine(options.Value.StoreRootFrom(environment), DirectoryName);
        _lifetime = options.Value.ImageLifetime;
    }

    /// <summary>
    /// Where one entry's poster sits inside <see cref="DirectoryName"/>: which kind of thing it
    /// is a poster of, then its id, and nothing of TMDB's.
    /// </summary>
    public static string PathOf(PosterSubject subject, int id) =>
        Path.Combine(FolderOf(subject), $"{id}.jpg");

    /// <summary>Which of the two keyspaces a poster is kept in, spelled as the routes spell it.</summary>
    private static string FolderOf(PosterSubject subject) =>
        subject == PosterSubject.Series ? "series" : "movies";

    /// <summary>
    /// The bytes of one series' or one movie's poster, from the store if it is there and still
    /// inside the limit, from TMDB if it is not, or null where there is no poster to be had —
    /// TMDB listing none, and TMDB having never heard of the id, are the same answer to whoever
    /// asked.
    /// </summary>
    /// <remarks>
    /// A null is not remembered. A poster is asked for about twice per adoption rather than once
    /// per render, so a negative kept here would save almost nothing and would go on being wrong
    /// about an entry that has since gained a poster.
    /// </remarks>
    /// <exception cref="HttpRequestException">TMDB could not be asked, or refused.</exception>
    /// <exception cref="JsonException">TMDB answered with something that is not what was asked for.</exception>
    public async Task<byte[]?> ReadOrFetchAsync(
        PosterSubject subject, int id, CancellationToken cancellationToken)
    {
        var path = Path.Combine(_directory, PathOf(subject, id));
        var stored = await StoreLifetime.ReadIfFreshAsync(path, _lifetime, _log, cancellationToken);
        if (stored is not null) return stored;

        var gate = Enter(subject, id);
        await gate.Waiting.WaitAsync(cancellationToken);
        try
        {
            // Whoever held the gate may have been fetching this very poster.
            if (await StoreLifetime.ReadIfFreshAsync(path, _lifetime, _log, cancellationToken) is { } fetched)
            {
                return fetched;
            }

            // Resolved per fetch rather than held: both of these reach TMDB through a typed
            // HttpClient, and a singleton holding one would pin a single handler for the life of
            // the server.
            using var scope = _services.CreateScope();

            // The cost of a miss: the details that say where the poster is, then the poster. Which
            // half of TMDB's API is asked is the whole of the difference between the two subjects.
            var posterPath = subject == PosterSubject.Series
                ? await scope.ServiceProvider.GetRequiredService<TmdbSeriesDetails>()
                    .PosterPathOfAsync(id, cancellationToken)
                : await scope.ServiceProvider.GetRequiredService<TmdbMovieDetails>()
                    .PosterPathOfAsync(id, cancellationToken);
            if (posterPath is null) return null;

            var images = scope.ServiceProvider.GetRequiredService<TmdbImages>();
            var bytes = await images.FetchPosterAsync(posterPath, cancellationToken);

            await StoreFile.WriteAsync(path, bytes, _log, cancellationToken);
            return bytes;
        }
        finally
        {
            gate.Waiting.Release();
            Leave(subject, id);
        }
    }

    /// <summary>One poster's gate, taken out for as long as anyone is waiting on it.</summary>
    private sealed class Gate
    {
        public SemaphoreSlim Waiting { get; } = new(1, 1);

        /// <summary>How many asks are holding or waiting on it, under the dictionary's lock.</summary>
        public int Holders { get; set; }
    }

    private Gate Enter(PosterSubject subject, int id)
    {
        lock (_fetching)
        {
            var key = (subject, id);
            if (!_fetching.TryGetValue(key, out var gate)) _fetching[key] = gate = new Gate();
            gate.Holders++;
            return gate;
        }
    }

    private void Leave(PosterSubject subject, int id)
    {
        lock (_fetching)
        {
            var key = (subject, id);
            if (!_fetching.TryGetValue(key, out var gate)) return;
            if (--gate.Holders == 0) _fetching.Remove(key);
        }
    }

}
