using System.Net;

namespace Season42.Bff.Tests;

/// <summary>
/// The poster of one series, asked for by the id a Series Match carried. Unlike the logo route
/// beside it, there is no snapshot to check an ask against — so what makes this route safe is
/// that a poster is never asked for by a TMDB path: the app has none to send (ADR-0012).
/// </summary>
public class PostersEndpointTests
{
    /// <summary>The id of Severance in <see cref="FakeTmdb.DefaultSeriesDetails"/>.</summary>
    private const int KnownSeries = 95396;

    /// <summary>The file TMDB's poster path in that answer names.</summary>
    private const string KnownPosterFile = "lFf6LLrQjYldcZItzOkGmMMigP7.jpg";

    [Fact]
    public async Task Poster_NotYetInTheStore_IsFetchedFromTmdbAndReturned()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("image/jpeg", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal(FakeTmdb.ImageBytes, await response.Content.ReadAsByteArrayAsync());
    }

    /// <summary>
    /// A miss pays twice — the details that say where the poster is, then the poster itself.
    /// It is the whole reason a hit is worth having.
    /// </summary>
    [Fact]
    public async Task Poster_NotYetInTheStore_IsAskedForAtTheOneSizeTheAppKeeps()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Single(factory.Tmdb.SeriesDetailsRequests);
        var request = Assert.Single(factory.Tmdb.ImageRequests);
        Assert.Equal(
            $"https://image.tmdb.org/t/p/{TmdbImages.PosterSize}/{KnownPosterFile}",
            request.RequestUri?.ToString());
    }

    /// <summary>
    /// The store keys on the id, so a hit costs no TMDB call at all — not even the details call
    /// that would be needed to turn an id back into TMDB's path.
    /// </summary>
    [Fact]
    public async Task Poster_AlreadyInTheStore_IsServedFromItAndTmdbIsNotAskedAgain()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var first = await client.GetAsync($"/series/{KnownSeries}/poster");
        var second = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        Assert.Equal(
            await first.Content.ReadAsByteArrayAsync(), await second.Content.ReadAsByteArrayAsync());
        Assert.Single(factory.Tmdb.ImageRequests);
        Assert.Single(factory.Tmdb.SeriesDetailsRequests);
    }

    [Fact]
    public async Task Poster_IsWrittenUnderItsId_AndOutlivesARestart()
    {
        var storePath = BffFactory.NewStoreDirectory();

        using (var first = new BffFactory(storePath: storePath))
        {
            var response = await first.CreateClient().GetAsync($"/series/{KnownSeries}/poster");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.True(File.Exists(first.PosterPathOf(KnownSeries)));
            // Never under the path TMDB published it at: that is the logo store's key, not this one.
            Assert.False(File.Exists(Path.Combine(first.PosterDirectory, KnownPosterFile)));
        }

        using var restarted = new BffFactory(storePath: storePath);
        var restartedResponse = await restarted.CreateClient().GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.OK, restartedResponse.StatusCode);
        Assert.Empty(restarted.Tmdb.ImageRequests);
        Assert.Empty(restarted.Tmdb.SeriesDetailsRequests);
    }

    /// <summary>
    /// Opening a search sheet asks for many posters at once, and the same one twice over is
    /// ordinary. Two asks for a poster nobody has yet must cost one fetch, not two.
    /// </summary>
    [Fact]
    public async Task Poster_AskedForTwiceAtOnce_CostsOneFetch()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        var held = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        factory.Tmdb.HoldAnswers = held;

        var first = client.GetAsync($"/series/{KnownSeries}/poster");
        // The second ask is made while the first is still unanswered — otherwise it would simply
        // be a store hit, and would prove nothing about two fetches at once.
        await FakeTmdb.WaitForAsync(() => factory.Tmdb.SeriesDetailsRequests.Count == 1);
        var second = client.GetAsync($"/series/{KnownSeries}/poster");

        // And it is given every chance to reach TMDB before the first is answered: the fake
        // records a request before it holds it, so an ungated second ask would already be
        // counted here. Without this the first could win the race and the test would quietly
        // become the store-hit test beside it.
        await Task.Delay(250);
        Assert.Single(factory.Tmdb.SeriesDetailsRequests);
        held.SetResult();

        foreach (var response in await Task.WhenAll(first, second))
        {
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal(FakeTmdb.ImageBytes, await response.Content.ReadAsByteArrayAsync());
        }

        Assert.Single(factory.Tmdb.ImageRequests);
        Assert.Single(factory.Tmdb.SeriesDetailsRequests);
    }

    /// <summary>
    /// Nothing negative is remembered: a poster is asked for about twice per adoption rather than
    /// per render, so remembering a "no" would save nothing and could be wrong by the next ask.
    /// </summary>
    [Fact]
    public async Task Poster_OfASeriesTmdbHasNoneFor_IsNotFoundEveryTime()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToDetailsWithNoPoster();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var first = await client.GetAsync($"/series/{KnownSeries}/poster");
        var second = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.NotFound, first.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, second.StatusCode);
        Assert.Empty(factory.Tmdb.ImageRequests);
        Assert.Equal(2, factory.Tmdb.SeriesDetailsRequests.Count);
    }

    [Fact]
    public async Task Poster_OfAnUnknownId_IsNotFound()
    {
        var tmdb = new FakeTmdb();
        tmdb.NotFoundOnDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series/404404/poster");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Empty(factory.Tmdb.ImageRequests);
        Assert.False(Directory.Exists(factory.PosterDirectory));
    }

    [Fact]
    public async Task Poster_WithTmdbUnreachable_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        Assert.False(File.Exists(factory.PosterPathOf(KnownSeries)));
    }

    /// <summary>
    /// TMDB knowing where the poster is and its image host then refusing to serve it is the same
    /// story to the user as the details call failing: this server could not get an answer.
    /// </summary>
    [Fact]
    public async Task Poster_TmdbCannotServe_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailImages();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        Assert.False(File.Exists(factory.PosterPathOf(KnownSeries)));
    }

    /// <summary>
    /// A TMDB that accepts the connection and then says nothing is as unreachable as one that
    /// refused, and the timeout that ends the wait is not this server's own fault.
    /// </summary>
    [Fact]
    public async Task Poster_WithTmdbSayingNothing_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.TimeOutOnDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>
    /// A poster is asked for by id and by nothing else. This is the whole of the route's
    /// validation, and it is what a route serving files off a caller's string would otherwise
    /// need an allowlist for: the route reads an int, so a path never reaches the store at all.
    /// </summary>
    [Theory]
    [InlineData("/series/severance/poster")]
    [InlineData("/series/..%2f..%2fappsettings.json/poster")]
    [InlineData("/series/%2e%2e%2f%2e%2e%2fappsettings.json/poster")]
    public async Task Poster_OfSomethingThatIsNotAnId_IsRefusedWithoutTouchingTheFilesystem(string url)
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync(url);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Empty(factory.Tmdb.SeriesDetailsRequests);
        Assert.Empty(factory.Tmdb.ImageRequests);
        Assert.False(Directory.Exists(factory.PosterDirectory));
    }

    /// <summary>
    /// The snapshot is the watch providers' story, and the poster route is not built on it. A
    /// server that has never reached TMDB for providers still serves posters perfectly well.
    /// </summary>
    [Fact]
    public async Task Poster_WithNoProviderSnapshot_IsStillServed()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailProviders();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
