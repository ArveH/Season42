namespace Season42.Bff;

/// <summary>
/// The one place that asks TMDB about a single movie. It hands back only what the detail screen
/// shows, and keeps nothing: opening a match is one cheap call, and a movie TMDB has only just
/// written an overview for is exactly the one a user is likely to be looking at.
/// </summary>
public sealed class TmdbMovieDetails(TmdbApi tmdb)
{
    /// <summary>
    /// What TMDB knows about the movie with this id, or null where it has never heard of it —
    /// an id nobody can look up is a different answer from an ask that could not be made, and
    /// the two reach the user as different statuses.
    /// </summary>
    /// <inheritdoc cref="TmdbApi.GetAsync{T}" path="/exception"/>
    public async Task<MovieDetails?> DetailsOfAsync(int id, CancellationToken cancellationToken)
    {
        var payload = await tmdb.GetIfFoundAsync<TmdbMovie>($"/movie/{id}", cancellationToken);
        if (payload is null) return null;

        // A title TMDB doesn't carry is empty, not absent: the app draws the original title
        // beside the title and the overview under it, and nothing there is worse for being blank.
        return new MovieDetails(
            payload.Title ?? "",
            payload.OriginalTitle ?? "",
            payload.Overview ?? "",
            // TMDB writes "no poster" as both a null and an empty string.
            !string.IsNullOrEmpty(payload.PosterPath));
    }

    /// <summary>
    /// TMDB's answer, read for the fields that matter. Everything else it sends — the runtime,
    /// the budget, the release date — has no property here and so is discarded. The poster path
    /// is read but never answered back: whether there is one is all the app is told (ADR-0012).
    /// </summary>
    private sealed record TmdbMovie(
        string? Title,
        string? OriginalTitle,
        string? Overview,
        string? PosterPath);
}
