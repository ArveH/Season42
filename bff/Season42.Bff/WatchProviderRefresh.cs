namespace Season42.Bff;

/// <summary>
/// Keeps <see cref="WatchProviderStore"/> current: once as the server starts, and every 24 hours
/// after that. A fetch that fails is logged and forgotten — the previous snapshot stands.
/// </summary>
public sealed class WatchProviderRefresh(
    IServiceProvider services, WatchProviderStore store, ILogger<WatchProviderRefresh> log) : IHostedService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(24);

    private CancellationTokenSource? _stopping;
    private Task? _loop;

    // A hand-rolled IHostedService rather than a BackgroundService, because the first fetch is
    // awaited before the server reports itself started — a BackgroundService runs after that point.
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        // The first fetch is awaited so that a server which reports itself started is a server
        // that has already tried; only a TMDB that is down leaves it answering 503.
        await RefreshAsync(cancellationToken);

        _stopping = new CancellationTokenSource();
        _loop = LoopAsync(_stopping.Token);
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_stopping is null) return;

        await _stopping.CancelAsync();
        if (_loop is not null)
        {
            await Task.WhenAny(_loop, Task.Delay(Timeout.Infinite, cancellationToken));
        }
    }

    /// <summary>Fetches once. Never throws: a failed refresh keeps the previous snapshot.</summary>
    public async Task RefreshAsync(CancellationToken cancellationToken)
    {
        try
        {
            // Resolved per refresh rather than held: TmdbWatchProviders is a typed HttpClient, and a
            // singleton holding one would pin a single handler for the life of the server.
            using var scope = services.CreateScope();
            var tmdb = scope.ServiceProvider.GetRequiredService<TmdbWatchProviders>();

            var providers = await tmdb.FetchAsync(cancellationToken);
            await store.UpdateAsync(providers, cancellationToken);

            log.LogInformation("Fetched {Count} watch providers from TMDB.", providers.Count);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            log.LogError(exception, "Fetching watch providers from TMDB failed; keeping the previous snapshot.");
        }
    }

    private async Task LoopAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(Interval);
        try
        {
            while (await timer.WaitForNextTickAsync(cancellationToken))
            {
                await RefreshAsync(cancellationToken);
            }
        }
        catch (OperationCanceledException)
        {
            // The server is stopping.
        }
    }
}
