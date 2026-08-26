using System.Net;
using System.Text.Json;

namespace Season42.Bff.Tests;

/// <summary>
/// What one match's details answer with. The search beside this one says which series the user
/// meant; this says what it is, and it is the only ask that has anything to say about seasons.
/// </summary>
public class SeriesDetailsEndpointTests
{
    [Fact]
    public async Task Details_AsksTmdbForTheSeriesThatWasOpened()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await DetailsOfAsync(client, 95396);

        var request = Assert.Single(factory.Tmdb.SeriesDetailsRequests);
        Assert.Equal("https://api.themoviedb.org/3/tv/95396", request.RequestUri?.ToString());
    }

    [Fact]
    public async Task Details_SendsTheTokenAsABearerHeader_NeverInTheQuery()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await DetailsOfAsync(client, 95396);

        var request = Assert.Single(factory.Tmdb.SeriesDetailsRequests);
        Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
        Assert.Equal("test-token", request.Headers.Authorization?.Parameter);
        Assert.DoesNotContain("test-token", request.RequestUri?.Query ?? "");
        Assert.DoesNotContain("api_key", request.RequestUri?.Query ?? "");
    }

    [Fact]
    public async Task Details_AnswersWithTheNameTheOriginalNameAndTheOverview()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 95396);

        Assert.Equal("Severance", details.Name);
        Assert.Equal("Severance (original)", details.OriginalName);
        Assert.StartsWith("Mark leads a team of office workers", details.Overview);
    }

    [Fact]
    public async Task Details_AnswersWithEverySeasonAndItsEpisodeCount()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 95396);

        Assert.Equal(
            [(0, 3), (1, 9), (2, 10)],
            details.Seasons.Select(season => (season.SeasonNumber, season.EpisodeCount)));
    }

    /// <summary>
    /// Season 0 is TMDB's specials, and whether a Tracked Series wants them is the app's
    /// product decision to make. The BFF translates TMDB's shape; it does not make that call.
    /// </summary>
    [Fact]
    public async Task Details_PassesSeasonZeroThrough()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 95396);

        Assert.Contains(details.Seasons, season => season.SeasonNumber == 0);
    }

    /// <summary>The seasons come back in TMDB's order, which is season order.</summary>
    [Fact]
    public async Task Details_KeepsTmdbsSeasonOrder()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToDetailsWith(PayloadOf(seasons: [(2, 10), (0, 3), (1, 9)]));
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 95396);

        Assert.Equal([2, 0, 1], details.Seasons.Select(season => season.SeasonNumber));
    }

    /// <summary>
    /// The networks, the ratings, the poster path and the taglines TMDB sends are all things
    /// nothing on the detail screen shows. Carrying them would be answering a question nobody
    /// asked — and so would answering the id back, which the app already has from the match it
    /// opened. Whether there *is* a poster is the one thing kept off TMDB's poster path, and it
    /// is a yes or a no rather than the path itself: a poster is asked for by id (ADR-0012).
    /// </summary>
    [Fact]
    public async Task Details_CarryNothingButTheNamedFields()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series/95396");
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());

        Assert.Equal(
            ["name", "originalName", "overview", "hasPoster", "seasons"],
            document.RootElement.EnumerateObject().Select(property => property.Name));
        Assert.Equal(
            ["seasonNumber", "episodeCount"],
            document.RootElement.GetProperty("seasons")[0].EnumerateObject()
                .Select(property => property.Name));
    }

    /// <summary>
    /// The app draws a placeholder where a series has no poster, and it must be able to do that
    /// without firing an ask it expects to be answered with a 404.
    /// </summary>
    [Fact]
    public async Task Details_SayWhetherThereIsAPosterToAskFor()
    {
        using var factory = new BffFactory();
        var withPoster = await DetailsOfAsync(factory.CreateClient(), 95396);

        var none = new FakeTmdb();
        none.RespondToDetailsWithNoPoster();
        using var without = new BffFactory(none);
        var withoutPoster = await DetailsOfAsync(without.CreateClient(), 95396);

        Assert.True(withPoster.HasPoster);
        Assert.False(withoutPoster.HasPoster);
    }

    /// <summary>TMDB sends an empty poster path for some series; that is no poster either.</summary>
    [Fact]
    public async Task Details_WithAnEmptyPosterPath_HaveNoPoster()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToDetailsWith("""{ "id": 7, "name": "Quiet", "poster_path": "", "seasons": [] }""");
        using var factory = new BffFactory(tmdb);

        var details = await DetailsOfAsync(factory.CreateClient(), 7);

        Assert.False(details.HasPoster);
    }

    /// <summary>
    /// A series TMDB knows under one name only sends that name once. The app shows the original
    /// name beside the name, and an absent one is empty rather than the answer failing to read.
    /// </summary>
    [Fact]
    public async Task Details_WithNoOriginalNameOrOverview_AreEmpty()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToDetailsWith("""{ "id": 7, "name": "Quiet", "seasons": [] }""");
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 7);

        Assert.Equal("Quiet", details.Name);
        Assert.Equal("", details.OriginalName);
        Assert.Equal("", details.Overview);
        Assert.False(details.HasPoster);
        Assert.Empty(details.Seasons);
    }

    [Fact]
    public async Task Details_OfAnUnknownId_IsNotFound()
    {
        var tmdb = new FakeTmdb();
        tmdb.NotFoundOnDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series/404404");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Details_WithTmdbUnreachable_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series/95396");

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
        tmdb.TimeOutOnDetails();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series/95396");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>An answer this server cannot read is the server behind it failing, not this one.</summary>
    [Fact]
    public async Task Details_WithTmdbAnsweringNonsense_IsABadGateway()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondToDetailsWith("this is not JSON");
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series/95396");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
    }

    /// <summary>
    /// Details are asked for by id and nothing else. A route that read a name here would be a
    /// second search, and searching is what the ask beside this one is for.
    /// </summary>
    [Fact]
    public async Task Details_OfSomethingThatIsNotAnId_IsNotFound()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/series/severance");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Empty(factory.Tmdb.SeriesDetailsRequests);
    }

    /// <summary>
    /// The snapshot is the watch providers' story. A server that has never reached TMDB for
    /// providers still answers for one series perfectly well.
    /// </summary>
    [Fact]
    public async Task Details_WithNoProviderSnapshot_StillAnswer()
    {
        var tmdb = new FakeTmdb();
        tmdb.FailProviders();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var details = await DetailsOfAsync(client, 95396);

        Assert.Equal("Severance", details.Name);
    }

    /// <summary>Nothing is kept: opening the same match twice asks TMDB twice.</summary>
    [Fact]
    public async Task Details_AreAskedOfTmdbEveryTime()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        await DetailsOfAsync(client, 95396);
        await DetailsOfAsync(client, 95396);

        Assert.Equal(2, factory.Tmdb.SeriesDetailsRequests.Count);
    }

    private static string PayloadOf(IEnumerable<(int Number, int Episodes)> seasons) =>
        JsonSerializer.Serialize(new
        {
            id = 95396,
            name = "Severance",
            original_name = "Severance",
            overview = "What it is about.",
            seasons = seasons.Select(season => new
            {
                season_number = season.Number,
                episode_count = season.Episodes,
                name = $"Season {season.Number}",
            }),
        });

    private static async Task<DetailedSeries> DetailsOfAsync(HttpClient client, int id)
    {
        var response = await client.GetAsync($"/series/{id}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var details = JsonSerializer.Deserialize<DetailedSeries>(
            await response.Content.ReadAsStringAsync(), JsonOptions);
        Assert.NotNull(details);
        return details;
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private sealed record DetailedSeries(
        string Name,
        string OriginalName,
        string Overview,
        bool HasPoster,
        IReadOnlyList<DetailedSeason> Seasons);

    private sealed record DetailedSeason(int SeasonNumber, int EpisodeCount);
}
