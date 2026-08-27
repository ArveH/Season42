using System.Net;
using System.Text.Json;

namespace Season42.Bff.Tests;

/// <summary>
/// The movie search, which answers as the series search beside it does: TMDB's own order, the
/// id to ask the next question with, the title to show, and nothing else.
/// </summary>
public class MoviesEndpointTests
{
    [Fact]
    public async Task Search_AsksTmdbForWhatWasSearchedFor()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await SearchAsync(client, "arrival & co");

        var request = Assert.Single(factory.Tmdb.MovieSearchRequests);
        Assert.Equal(
            "https://api.themoviedb.org/3/search/movie?query=arrival %26 co",
            request.RequestUri?.ToString());
    }

    [Fact]
    public async Task Search_SendsTheTokenAsABearerHeader_NeverInTheQuery()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await SearchAsync(client, "arrival");

        var request = Assert.Single(factory.Tmdb.MovieSearchRequests);
        Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
        Assert.Equal("test-token", request.Headers.Authorization?.Parameter);
        Assert.DoesNotContain("test-token", request.RequestUri?.Query ?? "");
        Assert.DoesNotContain("api_key", request.RequestUri?.Query ?? "");
    }

    [Fact]
    public async Task Search_AnswersWithTheIdAndTheTitle()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var matches = await SearchAsync(client, "arrival");

        Assert.Equal([(329865, "Arrival"), (438631, "Dune")],
            matches.Select(match => (match.Id, match.Title)));
    }

    /// <summary>
    /// The overview, the poster path and the paging TMDB sends are all things a later ask is for.
    /// A search that carried them would be answering a question nobody asked.
    /// </summary>
    [Fact]
    public async Task Search_CarriesNothingButTheIdAndTheTitle()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies?query=arrival");
        var json = await response.Content.ReadAsStringAsync();

        using var document = JsonDocument.Parse(json);
        var first = document.RootElement[0];
        Assert.Equal(["id", "title"], first.EnumerateObject().Select(property => property.Name));
    }

    [Fact]
    public async Task Search_KeepsTmdbsOrder()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToMoviesWith(PayloadOf([(3, "Zeta"), (1, "Alpha"), (2, "Mandalay")]));
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var matches = await SearchAsync(client, "a");

        Assert.Equal(["Zeta", "Alpha", "Mandalay"], matches.Select(match => match.Title));
    }

    [Fact]
    public async Task Search_MatchingNothing_IsAnEmptyArray()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToMoviesWith(PayloadOf([]));
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies?query=nosuchmovie");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Empty(await ReadAsync(response));
    }

    /// <summary>A match nobody could choose between is not a match.</summary>
    [Fact]
    public async Task Search_DropsAMatchWithNoTitle()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToMoviesWith("""
            { "results": [ { "id": 1, "title": "  " }, { "id": 2, "title": "Arrival" } ] }
            """);
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var matches = await SearchAsync(client, "a");

        Assert.Equal(2, Assert.Single(matches).Id);
    }

    [Fact]
    public async Task Search_Blank_IsABadRequest()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/movies?query=")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/movies?query=%20%20")).StatusCode);
    }

    [Fact]
    public async Task Search_Missing_IsABadRequest()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    /// <summary>A refused search costs no TMDB call at all.</summary>
    [Fact]
    public async Task Search_Blank_IsNotAskedOfTmdb()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await client.GetAsync("/movies?query=");

        Assert.Empty(factory.Tmdb.MovieSearchRequests);
    }

    [Fact]
    public async Task Search_WithTmdbUnreachable_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailMovies();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies?query=arrival");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>
    /// A TMDB that accepts the connection and then says nothing is as unreachable as one that
    /// refused, and the timeout that ends the wait must not read as this server's own fault.
    /// </summary>
    [Fact]
    public async Task Search_WithTmdbSayingNothing_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.TimeOutOnMovies();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies?query=arrival");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>An answer this server cannot read is the server behind it failing, not this one.</summary>
    [Fact]
    public async Task Search_WithTmdbAnsweringNonsense_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToMoviesWith("this is not JSON");
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/movies?query=arrival");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>
    /// The two searches are two asks of TMDB, and neither is the other's. A movie search asks
    /// for movies, and the series route is untouched by it.
    /// </summary>
    [Fact]
    public async Task Search_AsksForMoviesAndNotForSeries()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await SearchAsync(client, "arrival");

        Assert.Single(factory.Tmdb.MovieSearchRequests);
        Assert.Empty(factory.Tmdb.SeriesSearchRequests);
    }

    /// <summary>
    /// The snapshot is the watch providers' story, not the movies'. A server that has never
    /// reached TMDB for providers still searches for movies perfectly well.
    /// </summary>
    [Fact]
    public async Task Search_WithNoProviderSnapshot_StillAnswers()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailProviders();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var matches = await SearchAsync(client, "arrival");

        Assert.Equal("Arrival", matches[0].Title);
    }

    private static string PayloadOf(IEnumerable<(int Id, string Title)> movies)
    {
        var results = movies.Select(one => new
        {
            id = one.Id,
            title = one.Title,
            original_title = one.Title,
            overview = $"What {one.Title} is about.",
            poster_path = $"/{one.Id}.jpg",
            release_date = "2020-01-01",
        });
        return JsonSerializer.Serialize(new { page = 1, results, total_pages = 1 });
    }

    private static async Task<IReadOnlyList<MatchedMovie>> SearchAsync(HttpClient client, string query)
    {
        var response = await client.GetAsync($"/movies?query={Uri.EscapeDataString(query)}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return await ReadAsync(response);
    }

    private static async Task<IReadOnlyList<MatchedMovie>> ReadAsync(HttpResponseMessage response)
    {
        var json = await response.Content.ReadAsStringAsync();
        var results = JsonSerializer.Deserialize<List<MatchedMovie>>(json, JsonOptions);
        Assert.NotNull(results);
        return results;
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private sealed record MatchedMovie(int Id, string Title);
}
