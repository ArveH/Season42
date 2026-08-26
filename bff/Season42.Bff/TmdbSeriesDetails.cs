using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// The one place that asks TMDB about a single series. It hands back only what the detail
/// screen shows, and keeps nothing: opening a match is one cheap call, and a series that has
/// just gained a season is exactly the one a user is likely to be looking at.
/// </summary>
public sealed class TmdbSeriesDetails(HttpClient http, IOptions<TmdbOptions> options)
{
    // TMDB's v3 API, authenticated with the read access token in the header, exactly as the
    // search beside it is.
    private const string Endpoint = "https://api.themoviedb.org/3/tv";

    private static readonly JsonSerializerOptions TmdbFormat = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    /// <summary>
    /// What TMDB knows about the series with this id, or nil where it has never heard of it —
    /// an id nobody can look up is a different answer from an ask that could not be made, and
    /// the two reach the user as different statuses.
    /// </summary>
    /// <exception cref="HttpRequestException">TMDB could not be reached, or refused.</exception>
    /// <exception cref="TaskCanceledException">TMDB said nothing before the client's timeout.</exception>
    /// <exception cref="JsonException">TMDB answered with something that is not a series.</exception>
    public async Task<SeriesDetails?> DetailsOfAsync(int id, CancellationToken cancellationToken)
    {
        // The token goes in the header. TMDB also accepts it as a query parameter, where it would
        // end up in every access log and proxy cache between here and there.
        using var request = new HttpRequestMessage(HttpMethod.Get, $"{Endpoint}/{id}");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", options.Value.AccessToken);

        using var response = await http.SendAsync(request, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();

        var payload = await response.Content.ReadFromJsonAsync<TmdbSeries>(TmdbFormat, cancellationToken);
        if (payload is null) throw new JsonException("TMDB answered a series ask with null.");

        // A name TMDB doesn't carry is empty, not absent: the app draws the original name beside
        // the name and the overview under it, and nothing there is worse for being blank.
        return new SeriesDetails(
            payload.Id,
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
        int Id,
        string? Name,
        [property: JsonPropertyName("original_name")] string? OriginalName,
        string? Overview,
        List<TmdbSeason>? Seasons);

    private sealed record TmdbSeason(
        [property: JsonPropertyName("season_number")] int SeasonNumber,
        [property: JsonPropertyName("episode_count")] int EpisodeCount);
}
