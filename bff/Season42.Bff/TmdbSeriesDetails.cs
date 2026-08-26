namespace Season42.Bff;

/// <summary>
/// The one place that asks TMDB about a single series. It hands back only what the detail
/// screen shows, and keeps nothing: opening a match is one cheap call, and a series that has
/// just gained a season is exactly the one a user is likely to be looking at.
/// </summary>
public sealed class TmdbSeriesDetails(TmdbApi tmdb)
{
    /// <summary>
    /// What TMDB knows about the series with this id, or null where it has never heard of it —
    /// an id nobody can look up is a different answer from an ask that could not be made, and
    /// the two reach the user as different statuses.
    /// </summary>
    /// <inheritdoc cref="TmdbApi.GetAsync{T}" path="/exception"/>
    public async Task<SeriesDetails?> DetailsOfAsync(int id, CancellationToken cancellationToken)
    {
        var payload = await tmdb.GetIfFoundAsync<TmdbSeries>($"/tv/{id}", cancellationToken);
        if (payload is null) return null;

        // A name TMDB doesn't carry is empty, not absent: the app draws the original name beside
        // the name and the overview under it, and nothing there is worse for being blank.
        return new SeriesDetails(
            payload.Name ?? "",
            payload.OriginalName ?? "",
            payload.Overview ?? "",
            HasPoster(payload),
            // TMDB's order, which is season order, and season 0 among them.
            (payload.Seasons ?? [])
                .Select(season => new SeriesSeason(season.SeasonNumber, season.EpisodeCount))
                .ToList());
    }

    /// <summary>
    /// Where TMDB publishes this series' poster, or null where it has none and null again where
    /// it has never heard of the id — a poster nobody can fetch and a series nobody can look up
    /// are one answer to the caller, and the route answers both the same way (ADR-0012).
    /// </summary>
    /// <remarks>
    /// The same call the detail screen is drawn from, made again. It is what a store keyed on
    /// the id costs on a miss, and the reason a hit costs nothing at all.
    /// </remarks>
    /// <inheritdoc cref="TmdbApi.GetAsync{T}" path="/exception"/>
    public async Task<string?> PosterPathOfAsync(int id, CancellationToken cancellationToken)
    {
        var payload = await tmdb.GetIfFoundAsync<TmdbSeries>($"/tv/{id}", cancellationToken);
        return payload is not null && HasPoster(payload) ? payload.PosterPath : null;
    }

    /// <summary>TMDB writes "no poster" as both a null and an empty string.</summary>
    private static bool HasPoster(TmdbSeries payload) => !string.IsNullOrEmpty(payload.PosterPath);

    /// <summary>
    /// TMDB's answer, read for the fields that matter. Everything else it sends — the networks,
    /// the ratings, the air dates — has no property here and so is discarded. The poster path is
    /// read but never answered back: it is what this server fetches the poster with.
    /// </summary>
    private sealed record TmdbSeries(
        string? Name,
        string? OriginalName,
        string? Overview,
        string? PosterPath,
        List<TmdbSeason>? Seasons);

    private sealed record TmdbSeason(int SeasonNumber, int EpisodeCount);
}
