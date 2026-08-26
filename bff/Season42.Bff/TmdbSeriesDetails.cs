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
            // TMDB's order, which is season order, and season 0 among them.
            (payload.Seasons ?? [])
                .Select(season => new SeriesSeason(season.SeasonNumber, season.EpisodeCount))
                .ToList());
    }

    /// <summary>
    /// TMDB's answer, read for the fields that matter. Everything else it sends — the poster,
    /// the networks, the ratings, the air dates — has no property here and so is discarded.
    /// </summary>
    private sealed record TmdbSeries(
        string? Name,
        string? OriginalName,
        string? Overview,
        List<TmdbSeason>? Seasons);

    private sealed record TmdbSeason(int SeasonNumber, int EpisodeCount);
}
