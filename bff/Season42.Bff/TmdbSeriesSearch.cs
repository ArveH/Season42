namespace Season42.Bff;

/// <summary>
/// The one place that asks TMDB for series by name. It hands back only what a search answers
/// with, and keeps nothing: a search is one cheap call, and a stale answer would be visible to
/// the user as the series they just heard of not being listed.
/// </summary>
public sealed class TmdbSeriesSearch(TmdbApi tmdb)
{
    /// <summary>
    /// The series TMDB matched, in the order it served them — its own relevance order, which the
    /// BFF has nothing better to replace with. One page: what a search shows is the first page of
    /// matches, and paging is not something the app offers.
    /// </summary>
    /// <inheritdoc cref="TmdbApi.GetAsync{T}" path="/exception"/>
    public async Task<IReadOnlyList<SeriesMatch>> SearchAsync(string query, CancellationToken cancellationToken)
    {
        var payload = await tmdb.GetAsync<TmdbResponse>(
            $"/search/tv?query={Uri.EscapeDataString(query)}", cancellationToken);

        // A match with no name is nothing the user can choose between, so it is not a match.
        return (payload.Results ?? [])
            .Where(result => !string.IsNullOrWhiteSpace(result.Name))
            .Select(result => new SeriesMatch(result.Id, result.Name))
            .ToList();
    }

    /// <summary>
    /// TMDB's answer, read for the two fields that matter. Everything else it sends — the
    /// overview, the poster path, the paging — has no property here and so is discarded.
    /// </summary>
    private sealed record TmdbResponse(List<TmdbSeries>? Results);

    private sealed record TmdbSeries(int Id, string Name);
}
