using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// The one place that talks to TMDB. It asks for a region's TV watch providers and hands back
/// only what the BFF keeps.
/// </summary>
public sealed class TmdbWatchProviders(HttpClient http, IOptions<TmdbOptions> options)
{
    // TMDB's v3 API, authenticated with the read access token in the header.
    private const string Endpoint = "https://api.themoviedb.org/3/watch/providers/tv";

    private static readonly JsonSerializerOptions TmdbFormat = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    public async Task<IReadOnlyList<WatchProvider>> FetchAsync(CancellationToken cancellationToken)
    {
        var settings = options.Value;

        // The token goes in the header. TMDB also accepts it as a query parameter, where it would
        // end up in every access log and proxy cache between here and there.
        using var request = new HttpRequestMessage(
            HttpMethod.Get, $"{Endpoint}?watch_region={Uri.EscapeDataString(settings.WatchRegion)}");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", settings.AccessToken);

        using var response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        var payload = await response.Content.ReadFromJsonAsync<TmdbResponse>(TmdbFormat, cancellationToken);

        // A provider with no name cannot be searched for and one with no logo is the whole point
        // of the search, so neither is worth a row in the snapshot.
        return (payload?.Results ?? [])
            .Where(result => !string.IsNullOrWhiteSpace(result.ProviderName)
                             && !string.IsNullOrWhiteSpace(result.LogoPath))
            .Select(result => new WatchProvider(result.ProviderName, result.LogoPath, result.DisplayPriority))
            .ToList();
    }

    /// <summary>
    /// TMDB's answer, read for the three fields that matter. Everything else it sends — the
    /// provider id, the per-country priority map — has no property here and so is discarded.
    /// </summary>
    private sealed record TmdbResponse([property: JsonPropertyName("results")] List<TmdbProvider>? Results);

    private sealed record TmdbProvider(string ProviderName, string LogoPath, int DisplayPriority);
}
