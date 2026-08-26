using System.Net;

namespace Season42.Bff.Tests;

public class LogosEndpointTests
{
    /// <summary>The logo file of the Netflix row in <see cref="FakeTmdb.DefaultProviders"/>.</summary>
    private const string KnownLogo = "pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg";

    [Fact]
    public async Task Logo_NotYetInTheStore_IsFetchedFromTmdbAndReturned()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/logos/{KnownLogo}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("image/jpeg", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal(FakeTmdb.ImageBytes, await response.Content.ReadAsByteArrayAsync());
    }

    [Fact]
    public async Task Logo_IsAskedOfTmdbAtTheSizeRowsDrawAt()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await client.GetAsync($"/logos/{KnownLogo}");

        var request = Assert.Single(factory.Tmdb.ImageRequests);
        Assert.Equal(
            $"https://image.tmdb.org/t/p/w154/{KnownLogo}", request.RequestUri?.ToString());
    }

    [Fact]
    public async Task Logo_AlreadyInTheStore_IsServedFromItAndTmdbIsNotAskedAgain()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var first = await client.GetAsync($"/logos/{KnownLogo}");
        var second = await client.GetAsync($"/logos/{KnownLogo}");

        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        Assert.Equal(
            await first.Content.ReadAsByteArrayAsync(), await second.Content.ReadAsByteArrayAsync());
        Assert.Single(factory.Tmdb.ImageRequests);
    }

    [Fact]
    public async Task Logo_IsWrittenIntoTheConfiguredStore_AndOutlivesARestart()
    {
        var storePath = BffFactory.NewStoreDirectory();

        using (var first = new BffFactory(storePath: storePath))
        {
            Assert.Equal(HttpStatusCode.OK, (await first.CreateClient().GetAsync($"/logos/{KnownLogo}")).StatusCode);
            Assert.True(File.Exists(first.LogoPathOf(KnownLogo)));
        }

        using var restarted = new BffFactory(storePath: storePath);
        var response = await restarted.CreateClient().GetAsync($"/logos/{KnownLogo}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Empty(restarted.Tmdb.ImageRequests);
    }

    [Fact]
    public async Task Logo_TheSnapshotDoesNotKnow_IsRefusedWithoutTouchingTheFilesystem()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/logos/madeup.jpg");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Empty(factory.Tmdb.ImageRequests);
        Assert.False(Directory.Exists(factory.LogoDirectory));
    }

    [Theory]
    [InlineData("/logos/..%2f..%2fappsettings.json")]
    [InlineData("/logos/%2e%2e%2f%2e%2e%2fappsettings.json")]
    [InlineData("/logos/..%5c..%5cappsettings.json")]
    public async Task Logo_PathTraversal_IsRefusedByTheSameCheck(string url)
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync(url);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.False(Directory.Exists(factory.LogoDirectory));
    }

    [Fact]
    public async Task Logo_BeforeAnySnapshotExists_IsUnavailableRatherThanNotFound()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailProviders();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/logos/{KnownLogo}");

        // "I do not know yet" and "no such logo" are different answers (ADR-0007).
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Empty(factory.Tmdb.ImageRequests);
    }

    [Fact]
    public async Task Logo_PublishedAsAPng_IsServedAsOne()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToProvidersWith("""
            {
              "results": [
                { "display_priority": 1, "logo_path": "/viaplay.png", "provider_name": "Viaplay" }
              ]
            }
            """);
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/logos/viaplay.png");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("image/png", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task Logo_TmdbCannotServe_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailImages();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/logos/{KnownLogo}");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        Assert.False(File.Exists(factory.LogoPathOf(KnownLogo)));
    }
}
