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
