using System.Net;
using System.Text.Json;

namespace Season42.Bff.Tests;

/// <summary>
/// What one movie match's details answer with. The search beside this one says which movie the
/// user meant; this says what it is — and, unlike a series', it has nothing to say about seasons.
/// </summary>
public class MovieDetailsEndpointTests
{
    [Fact]
    public async Task Details_AsksTmdbForTheMovieThatWasOpened()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await DetailsOfAsync(client, 329865);

        var request = Assert.Single(factory.Tmdb.MovieDetailsRequests);
        Assert.Equal("https://api.themoviedb.org/3/movie/329865", request.RequestUri?.ToString());
    }

    [Fact]
    public async Task Details_SendsTheTokenAsABearerHeader_NeverInTheQuery()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await DetailsOfAsync(client, 329865);

        var request = Assert.Single(factory.Tmdb.MovieDetailsRequests);
        Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
        Assert.Equal("test-token", request.Headers.Authorization?.Parameter);
        Assert.DoesNotContain("test-token", request.RequestUri?.Query ?? "");
        Assert.DoesNotContain("api_key", request.RequestUri?.Query ?? "");
    }

    [Fact]
    public async Task Details_AnswerWithTheTitleTheOriginalTitleAndTheOverview()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 329865);

        Assert.Equal("Arrival", details.Title);
        Assert.Equal("Arrival (original)", details.OriginalTitle);
        Assert.StartsWith("Taking place after alien crafts land", details.Overview);
    }

    /// <summary>
    /// The runtime, the budget, the genres and the tagline TMDB sends are all things nothing on
    /// the detail screen shows. Carrying them would be answering a question nobody asked — and so
    /// would answering the id back, which the app already has from the match it opened. There are
    /// no seasons here at all: a movie is one thing to watch.
    /// </summary>
    [Fact]
    public async Task Details_CarryNothingButTheNamedFields()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies/329865");
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());

        Assert.Equal(
            ["title", "originalTitle", "overview", "hasPoster"],
            document.RootElement.EnumerateObject().Select(property => property.Name));
    }

    /// <summary>
    /// The poster is the next ticket's, but whether there is one to fetch is answered now: it is
    /// what lets the app draw a placeholder without firing an ask it expects to be refused.
    /// </summary>
    [Fact]
    public async Task Details_SayWhetherThereIsAPosterToAskFor()
    {
        using var factory = new BffFactory();
        var withPoster = await DetailsOfAsync(factory.CreateClient(), 329865);

        var none = new FakeTmdb();
        none.RespondToMovieDetailsWithNoPoster();
        using var without = new BffFactory(none);
        var withoutPoster = await DetailsOfAsync(without.CreateClient(), 329865);

        Assert.True(withPoster.HasPoster);
        Assert.False(withoutPoster.HasPoster);
    }

    /// <summary>TMDB sends an empty poster path for some movies; that is no poster either.</summary>
    [Fact]
    public async Task Details_WithAnEmptyPosterPath_HaveNoPoster()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToMovieDetailsWith("""{ "id": 7, "title": "Quiet", "poster_path": "" }""");
        using var factory = new BffFactory(tmdb);

        var details = await DetailsOfAsync(factory.CreateClient(), 7);

        Assert.False(details.HasPoster);
    }

    /// <summary>
    /// A movie TMDB knows under one title only sends that title once. The app shows the original
    /// title beside the title, and an absent one is empty rather than the answer failing to read.
    /// </summary>
    [Fact]
    public async Task Details_WithNoOriginalTitleOrOverview_AreEmpty()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToMovieDetailsWith("""{ "id": 7, "title": "Quiet" }""");
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 7);

        Assert.Equal("Quiet", details.Title);
        Assert.Equal("", details.OriginalTitle);
        Assert.Equal("", details.Overview);
        Assert.False(details.HasPoster);
    }

    [Fact]
    public async Task Details_OfAnUnknownId_IsNotFound()
    {
        var tmdb = new FakeTmdb();
        tmdb.NotFoundOnMovieDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies/404404");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Details_WithTmdbUnreachable_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailMovieDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies/329865");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>
    /// A TMDB that accepts the connection and then says nothing is as unreachable as one that
    /// refused, and the timeout that ends the wait must not read as this server's own fault.
    /// </summary>
    [Fact]
    public async Task Details_WithTmdbSayingNothing_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.TimeOutOnMovieDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies/329865");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>An answer this server cannot read is the server behind it failing, not this one.</summary>
    [Fact]
    public async Task Details_WithTmdbAnsweringNonsense_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToMovieDetailsWith("this is not JSON");
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies/329865");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>
    /// Details are asked for by id and nothing else. A route that read a title here would be a
    /// second search, and searching is what the ask beside this one is for.
    /// </summary>
    [Fact]
    public async Task Details_OfSomethingThatIsNotAnId_IsNotFound()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies/arrival");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Empty(factory.Tmdb.MovieDetailsRequests);
    }

    /// <summary>
    /// The snapshot is the watch providers' story. A server that has never reached TMDB for
    /// providers still answers for one movie perfectly well.
    /// </summary>
    [Fact]
    public async Task Details_WithNoProviderSnapshot_StillAnswer()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailProviders();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 329865);

        Assert.Equal("Arrival", details.Title);
    }

    /// <summary>Nothing is kept: opening the same match twice asks TMDB twice.</summary>
    [Fact]
    public async Task Details_AreAskedOfTmdbEveryTime()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await DetailsOfAsync(client, 329865);
        await DetailsOfAsync(client, 329865);

        Assert.Equal(2, factory.Tmdb.MovieDetailsRequests.Count);
    }

    /// <summary>
    /// A movie and a series with the same id are two different things, and the two routes ask
    /// TMDB two different questions about them.
    /// </summary>
    [Fact]
    public async Task Details_AskAboutAMovieAndNotAboutASeries()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await DetailsOfAsync(client, 329865);

        Assert.Single(factory.Tmdb.MovieDetailsRequests);
        Assert.Empty(factory.Tmdb.SeriesDetailsRequests);
    }

    private static async Task<DetailedMovie> DetailsOfAsync(HttpClient client, int id)
    {
        var response = await client.GetAsync($"/movies/{id}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var details = JsonSerializer.Deserialize<DetailedMovie>(
            await response.Content.ReadAsStringAsync(), JsonOptions);
        Assert.NotNull(details);
        return details;
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private sealed record DetailedMovie(
        string Title,
        string OriginalTitle,
        string Overview,
        bool HasPoster);
}
