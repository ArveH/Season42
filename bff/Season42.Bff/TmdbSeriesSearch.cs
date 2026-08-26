using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// The one place that asks TMDB for series by name. It hands back only what a search answers
/// with, and keeps nothing: a search is one cheap call, and a stale answer would be visible to
/// the user as the series they just heard of not being listed.
/// </summary>
public sealed class TmdbSeriesSearch(HttpClient http, IOptions<TmdbOptions> options)
{
    // TMDB's v3 API, authenticated with the read access token in the header, exactly as the
    // watch provider fetch beside it is.
    private const string Endpoint = "https://api.themoviedb.org/3/search/tv";

    private static readonly JsonSerializerOptions TmdbFormat = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    /// <summary>
    /// The series TMDB matched, in the order it served them — its own relevance order, which the
    /// BFF has nothing better to replace with. One page: what a search shows is the first page of
    /// matches, and paging is not something the app offers.
    /// </summary>
    /// <exception cref="HttpRequestException">TMDB could not be asked, or refused.</exception>
    public async Task<IReadOnlyList<SeriesMatch>> SearchAsync(string query, CancellationToken cancellationToken)
    {
        // The token goes in the header. TMDB also accepts it as a query parameter, where it would
        // end up in every access log and proxy cache between here and there.
        using var request = new HttpRequestMessage(
            HttpMethod.Get, $"{Endpoint}?query={Uri.EscapeDataString(query)}");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", options.Value.AccessToken);

        using var response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        var payload = await response.Content.ReadFromJsonAsync<TmdbResponse>(TmdbFormat, cancellationToken);

        // A match with no name is nothing the user can choose between, so it is not a match.
        return (payload?.Results ?? [])
            .Where(result => !string.IsNullOrWhiteSpace(result.Name))
            .Select(result => new SeriesMatch(result.Id, result.Name))
            .ToList();
    }

    /// <summary>
    /// TMDB's answer, read for the two fields that matter. Everything else it sends — the
    /// overview, the poster path, the paging — has no property here and so is discarded.
    /// </summary>
    private sealed record TmdbResponse([property: JsonPropertyName("results")] List<TmdbSeries>? Results);

    private sealed record TmdbSeries(int Id, string Name);
}
