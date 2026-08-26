using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// The one place that asks TMDB for a region's TV watch providers. It hands back only what the
/// BFF keeps.
/// </summary>
public sealed class TmdbWatchProviders(TmdbApi tmdb, IOptions<TmdbOptions> options)
{
    /// <inheritdoc cref="TmdbApi.GetAsync{T}" path="/exception"/>
    public async Task<IReadOnlyList<WatchProvider>> FetchAsync(CancellationToken cancellationToken)
    {
        var region = Uri.EscapeDataString(options.Value.WatchRegion);
        var payload = await tmdb.GetAsync<TmdbResponse>(
            $"/watch/providers/tv?watch_region={region}", cancellationToken);

        // A provider with no name cannot be searched for and one with no logo is the whole point
        // of the search, so neither is worth a row in the snapshot.
        return (payload.Results ?? [])
            .Where(result => !string.IsNullOrWhiteSpace(result.ProviderName)
                             && !string.IsNullOrWhiteSpace(result.LogoPath))
            .Select(result => new WatchProvider(result.ProviderName, result.LogoPath, result.DisplayPriority))
            .ToList();
    }

    /// <summary>
    /// TMDB's answer, read for the three fields that matter. Everything else it sends — the
    /// provider id, the per-country priority map — has no property here and so is discarded.
    /// </summary>
    private sealed record TmdbResponse(List<TmdbProvider>? Results);

    private sealed record TmdbProvider(string ProviderName, string LogoPath, int DisplayPriority);
}
