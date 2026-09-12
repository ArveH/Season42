using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace Season42.Bff.Tests;

/// <summary>
/// The real app, wired to a <see cref="FakeTmdb"/> instead of the network. Tests drive the
/// endpoints through it; only the outermost HTTP handler is swapped.
/// </summary>
public sealed class BffFactory : WebApplicationFactory<Program>
{
    public BffFactory(FakeTmdb? tmdb = null, string? storePath = null)
    {
        Tmdb = tmdb ?? new FakeTmdb();
        StorePath = storePath ?? NewStoreDirectory();
    }

    public FakeTmdb Tmdb { get; }

    /// <summary>Where this server keeps what it fetched — a directory of its own per test.</summary>
    public string StorePath { get; }

    /// <summary>
    /// How many requests one caller may make per window. Left at the deployment's own default
    /// unless a test sets it, which a test of the limit does so a burst is a handful of requests
    /// rather than a minute of them. Set it before the first <c>CreateClient</c>.
    /// </summary>
    public int? PermitsPerWindow { get; set; }

    /// <summary>
    /// How long a window lasts. Left at the deployment's own default unless a test sets it; a
    /// test that waits for permits to come back sets it to about a second, because the default
    /// minute is not a thing to wait for. Set it before the first <c>CreateClient</c>.
    /// </summary>
    public int? WindowSeconds { get; set; }

    /// <summary>The snapshot file inside <see cref="StorePath"/>.</summary>
    public string SnapshotPath => Path.Combine(StorePath, TmdbOptions.SnapshotFileName);

    /// <summary>Where the logo bytes land inside <see cref="StorePath"/>.</summary>
    public string LogoDirectory => Path.Combine(StorePath, LogoStore.DirectoryName);

    /// <summary>Where one logo's bytes land.</summary>
    public string LogoPathOf(string file) => Path.Combine(LogoDirectory, file);

    /// <summary>Where the poster bytes land inside <see cref="StorePath"/>.</summary>
    public string PosterDirectory => Path.Combine(StorePath, PosterStore.DirectoryName);

    /// <summary>
    /// Where one entry's poster lands — under its id and under the kind of thing it is a poster
    /// of, never under TMDB's path.
    /// </summary>
    public string PosterPathOf(PosterSubject subject, int id) =>
        Path.Combine(PosterDirectory, PosterStore.PathOf(subject, id));

    /// <summary>Runs a refresh on demand — what the daily timer would otherwise have to wait for.</summary>
    public Task RefreshAsync() =>
        Services.GetRequiredService<WatchProviderRefresh>().RefreshAsync(CancellationToken.None);

    public static string NewStoreDirectory()
    {
        var directory = Path.Combine(Path.GetTempPath(), "season42-bff-tests", Guid.NewGuid().ToString("n"));
        Directory.CreateDirectory(directory);
        return directory;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting(TmdbOptions.AccessTokenKey, "test-token");
        builder.UseSetting("Tmdb:WatchRegion", "NO");
        builder.UseSetting("Tmdb:LogoStorePath", StorePath);

        if (PermitsPerWindow is { } permits)
        {
            builder.UseSetting($"{RateLimitOptions.SectionName}:{nameof(RateLimitOptions.PermitsPerWindow)}",
                permits.ToString());
        }

        if (WindowSeconds is { } window)
        {
            builder.UseSetting($"{RateLimitOptions.SectionName}:{nameof(RateLimitOptions.WindowSeconds)}",
                window.ToString());
        }

        builder.ConfigureTestServices(services =>
        {
            // Two clients to swap, not one per ask: everything on TMDB's API shares TmdbApi's,
            // and the image host has its own.
            services.AddHttpClient<TmdbApi>()
                .ConfigurePrimaryHttpMessageHandler(() => Tmdb);
            services.AddHttpClient<TmdbImages>()
                .ConfigurePrimaryHttpMessageHandler(() => Tmdb);
        });
    }
}
