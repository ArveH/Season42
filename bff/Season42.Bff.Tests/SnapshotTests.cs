using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;

namespace Season42.Bff.Tests;

public class SnapshotTests
{
    [Fact]
    public void Fetch_AsksTmdbForTheConfiguredRegionsTvProviders()
    {
        using var factory = new BffFactory();
        factory.CreateClient();

        var request = Assert.Single(factory.Tmdb.Requests);
        Assert.Equal(
            "https://api.themoviedb.org/3/watch/providers/tv?watch_region=NO",
            request.RequestUri?.ToString());
    }

    [Fact]
    public void Fetch_SendsTheTokenAsABearerHeader_NeverInTheQuery()
    {
        using var factory = new BffFactory();
        factory.CreateClient();

        var request = Assert.Single(factory.Tmdb.Requests);
        Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
        Assert.Equal("test-token", request.Headers.Authorization?.Parameter);
        Assert.DoesNotContain("test-token", request.RequestUri?.Query ?? "");
        Assert.DoesNotContain("api_key", request.RequestUri?.Query ?? "");
    }

    [Fact]
    public async Task Snapshot_KeepsOnlyTheNameLogoPathAndDisplayPriority()
    {
        using var factory = new BffFactory();
        factory.CreateClient();

        var written = await File.ReadAllTextAsync(factory.SnapshotPath);

        Assert.Contains("Netflix", written);
        Assert.DoesNotContain("display_priorities", written);
        Assert.DoesNotContain("\"AR\"", written);
        Assert.DoesNotContain("337", written);
    }

    [Fact]
    public async Task Snapshot_IsWrittenToDiskAndReadBackOnRestart()
    {
        var storePath = BffFactory.NewStoreDirectory();

        using (var first = new BffFactory(storePath: storePath))
        {
            first.CreateClient();
            Assert.True(File.Exists(first.SnapshotPath));
        }

        var unreachable = new FakeTmdb();
        unreachable.FailProviders();
        using var restarted = new BffFactory(unreachable, storePath);
        var client = restarted.CreateClient();

        var results = await ProvidersEndpointTests.SearchAsync(client, "netflix");

        Assert.Single(results);
    }

    [Fact]
    public async Task Refresh_ThatFails_KeepsThePreviousSnapshot()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        Assert.Single(await ProvidersEndpointTests.SearchAsync(client, "netflix"));

        factory.Tmdb.FailProviders();
        await factory.RefreshAsync();

        Assert.Single(await ProvidersEndpointTests.SearchAsync(client, "netflix"));
    }

    [Fact]
    public async Task Refresh_ThatSucceeds_ReplacesTheSnapshot()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        factory.Tmdb.RespondToProvidersWith(ProvidersEndpointTests.PayloadOf([("Viaplay", 3)]));
        await factory.RefreshAsync();

        Assert.Empty(await ProvidersEndpointTests.SearchAsync(client, "netflix"));
        Assert.Single(await ProvidersEndpointTests.SearchAsync(client, "viaplay"));
    }

    [Fact]
    public void Startup_WithoutAToken_FailsWithAClearMessage()
    {
        using var factory = new BffFactory();
        using var withoutToken = factory.WithWebHostBuilder(
            builder => builder.UseSetting(TmdbOptions.AccessTokenKey, ""));

        var failure = Record.Exception(() => withoutToken.CreateClient());

        Assert.NotNull(failure);
        Assert.Contains(TmdbOptions.AccessTokenKey, failure.ToString());
    }

    [Fact]
    public async Task Snapshot_OnDisk_HoldsWhatTheEndpointServes()
    {
        using var factory = new BffFactory();
        factory.CreateClient();

        var providers = JsonSerializer.Deserialize<List<ProviderOnDisk>>(
            await File.ReadAllTextAsync(factory.SnapshotPath), ProvidersEndpointTests.JsonOptions);

        Assert.NotNull(providers);
        Assert.Equal(4, providers.Count);
        Assert.All(providers, provider =>
        {
            Assert.False(string.IsNullOrWhiteSpace(provider.Name));
            Assert.StartsWith("/", provider.LogoPath);
        });
    }

    [Fact]
    public async Task Snapshot_DropsProvidersWithNoNameOrNoLogo()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToProvidersWith("""
            {
              "results": [
                { "display_priority": 1, "logo_path": "/real.jpg", "provider_name": "Real" },
                { "display_priority": 2, "logo_path": "/nameless.jpg", "provider_name": "" },
                { "display_priority": 3, "logo_path": "", "provider_name": "Logoless" }
              ]
            }
            """);
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        Assert.Single(await ProvidersEndpointTests.SearchAsync(client, "real"));
        Assert.Empty(await ProvidersEndpointTests.SearchAsync(client, "logoless"));
    }

    [Fact]
    public async Task Snapshot_ThatIsEmptyOnDisk_IsStillASnapshot()
    {
        var storePath = BffFactory.NewStoreDirectory();
        await File.WriteAllTextAsync(Path.Combine(storePath, TmdbOptions.SnapshotFileName), "[]");

        var unreachable = new FakeTmdb();
        unreachable.FailProviders();
        using var factory = new BffFactory(unreachable, storePath);
        var client = factory.CreateClient();

        // "TMDB knows of none" is an answer; only "nothing fetched yet" is a 503.
        Assert.Empty(await ProvidersEndpointTests.SearchAsync(client, "netflix"));
    }

    private sealed record ProviderOnDisk(string Name, string LogoPath, int DisplayPriority);
}
