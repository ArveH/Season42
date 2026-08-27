using System.Net;

namespace Season42.Bff.Tests;

/// <summary>
/// The poster of one movie, asked for by the id a Movie Match carried. The series poster route
/// beside it on the same terms and out of the same store, so what these prove of a movie is what
/// <see cref="PostersEndpointTests"/> proves of a series — with one thing added that neither
/// proves alone: TMDB numbers its movies and its series apart, so an id is only half a key.
/// </summary>
public class MoviePostersEndpointTests
{
    /// <summary>The id of Arrival in <see cref="FakeTmdb.DefaultMovieDetails"/>.</summary>
    private const int KnownMovie = 329865;

    /// <summary>The file TMDB's poster path in that answer names.</summary>
    private const string KnownPosterFile = "x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg";

    [Fact]
    public async Task Poster_NotYetInTheStore_IsFetchedFromTmdbAndReturned()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/movies/{KnownMovie}/poster");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("image/jpeg", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal(FakeTmdb.ImageBytes, await response.Content.ReadAsByteArrayAsync());
    }

    /// <summary>
    /// A miss pays twice — the details that say where the poster is, then the poster itself — and
    /// it is TMDB's movie half that is asked, not the series half the route beside this asks.
    /// </summary>
    [Fact]
    public async Task Poster_NotYetInTheStore_IsAskedForAtTheOneSizeTheAppKeeps()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await client.GetAsync($"/movies/{KnownMovie}/poster");

        Assert.Single(factory.Tmdb.MovieDetailsRequests);
        Assert.Empty(factory.Tmdb.SeriesDetailsRequests);
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

        var first = await client.GetAsync($"/movies/{KnownMovie}/poster");
        var second = await client.GetAsync($"/movies/{KnownMovie}/poster");

        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        Assert.Equal(
            await first.Content.ReadAsByteArrayAsync(), await second.Content.ReadAsByteArrayAsync());
        Assert.Single(factory.Tmdb.ImageRequests);
        Assert.Single(factory.Tmdb.MovieDetailsRequests);
    }

    [Fact]
    public async Task Poster_IsWrittenUnderItsId_AndOutlivesARestart()
    {
        var storePath = BffFactory.NewStoreDirectory();

        using (var first = new BffFactory(storePath: storePath))
        {
            var response = await first.CreateClient().GetAsync($"/movies/{KnownMovie}/poster");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.True(File.Exists(first.PosterPathOf(PosterSubject.Movie, KnownMovie)));
            // Never under the path TMDB published it at: that is the logo store's key, not this one.
            Assert.False(File.Exists(Path.Combine(first.PosterDirectory, KnownPosterFile)));
        }

        using var restarted = new BffFactory(storePath: storePath);
        var restartedResponse = await restarted.CreateClient().GetAsync($"/movies/{KnownMovie}/poster");

        Assert.Equal(HttpStatusCode.OK, restartedResponse.StatusCode);
        Assert.Empty(restarted.Tmdb.ImageRequests);
        Assert.Empty(restarted.Tmdb.MovieDetailsRequests);
    }

    /// <summary>
    /// An id is only half a key. TMDB numbers its movies and its series separately, so the same
    /// number names two different things and their posters must not stand in for one another.
    /// </summary>
    [Fact]
    public async Task Poster_OfAMovieAndOfASeriesWithTheSameId_AreKeptApart()
    {
        var tmdb = new FakeTmdb();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        await client.GetAsync($"/series/{KnownMovie}/poster");
        await client.GetAsync($"/movies/{KnownMovie}/poster");

        // Each paid for its own miss: the movie's ask was not answered out of the series' file.
        Assert.Single(factory.Tmdb.SeriesDetailsRequests);
        Assert.Single(factory.Tmdb.MovieDetailsRequests);
        Assert.Equal(2, factory.Tmdb.ImageRequests.Count);
        Assert.True(File.Exists(factory.PosterPathOf(PosterSubject.Series, KnownMovie)));
        Assert.True(File.Exists(factory.PosterPathOf(PosterSubject.Movie, KnownMovie)));
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

        var first = client.GetAsync($"/movies/{KnownMovie}/poster");
        // The second ask is made while the first is still unanswered — otherwise it would simply
        // be a store hit, and would prove nothing about two fetches at once.
        await FakeTmdb.WaitForAsync(() => factory.Tmdb.MovieDetailsRequests.Count == 1);
        var second = client.GetAsync($"/movies/{KnownMovie}/poster");

        // And it is given every chance to reach TMDB before the first is answered: the fake
        // records a request before it holds it, so an ungated second ask would already be
        // counted here.
        await Task.Delay(250);
        Assert.Single(factory.Tmdb.MovieDetailsRequests);
        held.SetResult();

        foreach (var response in await Task.WhenAll(first, second))
        {
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal(FakeTmdb.ImageBytes, await response.Content.ReadAsByteArrayAsync());
        }

        Assert.Single(factory.Tmdb.ImageRequests);
        Assert.Single(factory.Tmdb.MovieDetailsRequests);
    }

    /// <summary>
    /// Nothing negative is remembered: a poster is asked for about twice per adoption rather than
    /// per render, so remembering a "no" would save nothing and could be wrong by the next ask.
    /// </summary>
    [Fact]
    public async Task Poster_OfAMovieTmdbHasNoneFor_IsNotFoundEveryTime()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToMovieDetailsWithNoPoster();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var first = await client.GetAsync($"/movies/{KnownMovie}/poster");
        var second = await client.GetAsync($"/movies/{KnownMovie}/poster");

        Assert.Equal(HttpStatusCode.NotFound, first.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, second.StatusCode);
        Assert.Empty(factory.Tmdb.ImageRequests);
        Assert.Equal(2, factory.Tmdb.MovieDetailsRequests.Count);
    }

    [Fact]
    public async Task Poster_OfAnUnknownId_IsNotFound()
    {
        var tmdb = new FakeTmdb();
        tmdb.NotFoundOnMovieDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies/404404/poster");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Empty(factory.Tmdb.ImageRequests);
        Assert.False(Directory.Exists(factory.PosterDirectory));
    }

    [Fact]
    public async Task Poster_WithTmdbUnreachable_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailMovieDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/movies/{KnownMovie}/poster");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        Assert.False(File.Exists(factory.PosterPathOf(PosterSubject.Movie, KnownMovie)));
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

        var response = await client.GetAsync($"/movies/{KnownMovie}/poster");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        Assert.False(File.Exists(factory.PosterPathOf(PosterSubject.Movie, KnownMovie)));
    }

    /// <summary>
    /// A TMDB that accepts the connection and then says nothing is as unreachable as one that
    /// refused, and the timeout that ends the wait is not this server's own fault.
    /// </summary>
    [Fact]
    public async Task Poster_WithTmdbSayingNothing_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.TimeOutOnMovieDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync($"/movies/{KnownMovie}/poster");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>
    /// A poster is asked for by id and by nothing else. This is the whole of the route's
    /// validation, and it is what a route serving files off a caller's string would otherwise
    /// need an allowlist for: the route reads an int, so a path never reaches the store at all.
    /// </summary>
    [Theory]
    [InlineData("/movies/arrival/poster")]
    [InlineData("/movies/..%2f..%2fappsettings.json/poster")]
    [InlineData("/movies/%2e%2e%2f%2e%2e%2fappsettings.json/poster")]
    public async Task Poster_OfSomethingThatIsNotAnId_IsRefusedWithoutTouchingTheFilesystem(string url)
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync(url);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Empty(factory.Tmdb.MovieDetailsRequests);
        Assert.Empty(factory.Tmdb.ImageRequests);
        Assert.False(Directory.Exists(factory.PosterDirectory));
    }
}
