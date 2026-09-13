using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// Sweeps the Logo Store and the Poster Store of everything that has aged past
/// <see cref="TmdbOptions.ImageLifetime"/>: once as the server starts, and every 24 hours after
/// that, beside the <see cref="WatchProviderRefresh"/> that keeps the snapshot current.
/// </summary>
/// <remarks>
/// The sweep is the half of the limit that reaches an image nobody asks for again; the stores
/// themselves refuse to serve an aged image whether or not a sweep has been round yet
/// (ADR-0020). Sweeping as the server starts rather than waiting a day for the first tick is what
/// makes the limit independent of the machine staying up: time spent stopped is still time.
/// </remarks>
public sealed class StoreEviction : IHostedService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(24);

    private readonly string[] _directories;
    private readonly TimeSpan _lifetime;
    private readonly ILogger<StoreEviction> _log;

    private CancellationTokenSource? _stopping;
    private Task? _loop;

    public StoreEviction(
        IOptions<TmdbOptions> options, IHostEnvironment environment, ILogger<StoreEviction> log)
    {
        _log = log;
        _lifetime = options.Value.ImageLifetime;
        var root = options.Value.StoreRootFrom(environment);

        // The two image stores and not the store root, so that the snapshot beside them — which
        // is not an image, and which the daily refresh rewrites — is never swept out from under
        // a TMDB that has gone quiet.
        _directories =
        [
            Path.Combine(root, LogoStore.DirectoryName),
            Path.Combine(root, PosterStore.DirectoryName),
        ];
    }

    // The first sweep is started here and deliberately not waited for, unlike the first fetch of
    // the refresh beside it. Nothing this server answers depends on a sweep having finished — the
    // stores refuse an aged image themselves — and this machine stops when nobody is asking
    // (ADR-0015), so a walk of both stores on the way up would be a cold start's cost every time.
    public Task StartAsync(CancellationToken cancellationToken)
    {
        _stopping = new CancellationTokenSource();
        _loop = LoopAsync(_stopping.Token);
        return Task.CompletedTask;
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

    /// <summary>
    /// Sweeps both stores once. Never throws: a sweep that could not finish leaves what it could
    /// not remove for the next one, and nothing a caller asked for depends on it.
    /// </summary>
    public void Sweep()
    {
        var evicted = 0;
        foreach (var directory in _directories)
        {
            // Each store on its own, so that one of them faulting mid-walk — a file moving under
            // the sweep, a volume that went away — does not quietly leave the other unswept until
            // tomorrow. The two have nothing to do with each other but the limit they share.
            try
            {
                evicted += StoreLifetime.EvictAgedUnder(directory, _lifetime, _log);
            }
            catch (Exception exception)
            {
                _log.LogError(
                    exception,
                    "Sweeping {Directory} failed; what is in it stands until the next sweep.",
                    directory);
            }
        }

        if (evicted > 0) _log.LogInformation("Evicted {Count} images that had aged past the limit.", evicted);
    }

    private async Task LoopAsync(CancellationToken cancellationToken)
    {
        // Off the startup path before the first sweep, so the walk is the server's own work rather
        // than something a caller waiting on a cold start pays for.
        await Task.Yield();
        Sweep();

        using var timer = new PeriodicTimer(Interval);
        try
        {
            while (await timer.WaitForNextTickAsync(cancellationToken))
            {
                Sweep();
            }
        }
        catch (OperationCanceledException)
        {
            // The server is stopping.
        }
    }
}
