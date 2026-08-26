using System.Net;
using System.Text.Json;

namespace Season42.Bff.Tests;

public class SeriesEndpointTests
{
    [Fact]
    public async Task Search_AsksTmdbForWhatWasSearchedFor()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await SearchAsync(client, "severance & co");

        var request = Assert.Single(factory.Tmdb.SeriesSearchRequests);
        Assert.Equal(
            "https://api.themoviedb.org/3/search/tv?query=severance %26 co",
            request.RequestUri?.ToString());
    }

    [Fact]
    public async Task Search_SendsTheTokenAsABearerHeader_NeverInTheQuery()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await SearchAsync(client, "severance");

        var request = Assert.Single(factory.Tmdb.SeriesSearchRequests);
        Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
        Assert.Equal("test-token", request.Headers.Authorization?.Parameter);
        Assert.DoesNotContain("test-token", request.RequestUri?.Query ?? "");
        Assert.DoesNotContain("api_key", request.RequestUri?.Query ?? "");
    }

    [Fact]
    public async Task Search_AnswersWithTheIdAndTheName()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var matches = await SearchAsync(client, "severance");

        Assert.Equal([(95396, "Severance"), (1399, "Game of Thrones")],
            matches.Select(match => (match.Id, match.Name)));
    }

    /// <summary>
    /// The overview, the poster path and the paging TMDB sends are all things a later ask is for.
    /// A search that carried them would be answering a question nobody asked.
    /// </summary>
    [Fact]
    public async Task Search_CarriesNothingButTheIdAndTheName()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series?query=severance");
        var json = await response.Content.ReadAsStringAsync();

        using var document = JsonDocument.Parse(json);
        var first = document.RootElement[0];
        Assert.Equal(["id", "name"], first.EnumerateObject().Select(property => property.Name));
    }

    [Fact]
    public async Task Search_KeepsTmdbsOrder()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToSeriesWith(PayloadOf([(3, "Zeta"), (1, "Alpha"), (2, "Mandalay")]));
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var matches = await SearchAsync(client, "a");

        Assert.Equal(["Zeta", "Alpha", "Mandalay"], matches.Select(match => match.Name));
    }

    [Fact]
    public async Task Search_MatchingNothing_IsAnEmptyArray()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToSeriesWith(PayloadOf([]));
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series?query=nosuchseries");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Empty(await ReadAsync(response));
    }

    /// <summary>A match nobody could choose between is not a match.</summary>
    [Fact]
    public async Task Search_DropsAMatchWithNoName()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToSeriesWith("""
            { "results": [ { "id": 1, "name": "  " }, { "id": 2, "name": "Severance" } ] }
            """);
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var matches = await SearchAsync(client, "s");

        Assert.Equal(2, Assert.Single(matches).Id);
    }

    [Fact]
    public async Task Search_Blank_IsABadRequest()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/series?query=")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/series?query=%20%20")).StatusCode);
    }

    [Fact]
    public async Task Search_Missing_IsABadRequest()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    /// <summary>A refused search costs no TMDB call at all.</summary>
    [Fact]
    public async Task Search_Blank_IsNotAskedOfTmdb()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await client.GetAsync("/series?query=");

        Assert.Empty(factory.Tmdb.SeriesSearchRequests);
    }

    [Fact]
    public async Task Search_WithTmdbUnreachable_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailSeries();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series?query=severance");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>
    /// The snapshot is the watch providers' story, not the series'. A server that has never
    /// reached TMDB for providers still searches for series perfectly well.
    /// </summary>
    [Fact]
    public async Task Search_WithNoProviderSnapshot_StillAnswers()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailProviders();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var matches = await SearchAsync(client, "severance");

        Assert.Equal("Severance", matches[0].Name);
    }

    private static string PayloadOf(IEnumerable<(int Id, string Name)> series)
    {
        var results = series.Select(one => new
        {
            id = one.Id,
            name = one.Name,
            original_name = one.Name,
            overview = $"What {one.Name} is about.",
            poster_path = $"/{one.Id}.jpg",
            first_air_date = "2020-01-01",
        });
        return JsonSerializer.Serialize(new { page = 1, results, total_pages = 1 });
    }

    private static async Task<IReadOnlyList<SeriesResult>> SearchAsync(HttpClient client, string query)
    {
        var response = await client.GetAsync($"/series?query={Uri.EscapeDataString(query)}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return await ReadAsync(response);
    }

    private static async Task<IReadOnlyList<SeriesResult>> ReadAsync(HttpResponseMessage response)
    {
        var json = await response.Content.ReadAsStringAsync();
        var results = JsonSerializer.Deserialize<List<SeriesResult>>(json, JsonOptions);
        Assert.NotNull(results);
        return results;
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private sealed record SeriesResult(int Id, string Name);
}
