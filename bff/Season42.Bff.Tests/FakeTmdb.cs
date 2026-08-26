using System.Net;
using System.Net.Http.Headers;
using System.Text;

namespace Season42.Bff.Tests;

/// <summary>
/// Stands in for TMDB at the composition root — both the API it answers searches from and the
/// image host it serves logos from. Every test runs against this: nothing in this test project
/// reaches the network.
/// </summary>
/// <remarks>
/// It answers by path, not by host. The watch provider list and the series search are two
/// different asks on one API host, so the host alone no longer says which answer is wanted; a
/// path this double has not been taught is a 404, so a route asking for something unexpected
/// fails as a wrong answer rather than quietly taking another route's.
/// </remarks>
public sealed class FakeTmdb : HttpMessageHandler
{
    /// <summary>The region's TV watch providers — what the daily snapshot is fetched from.</summary>
    public const string WatchProvidersPath = "/3/watch/providers/tv";

    /// <summary>Series by name.</summary>
    public const string SeriesSearchPath = "/3/search/tv";

    /// <summary>One series by id — everything TMDB knows about it. The id follows this.</summary>
    public const string SeriesDetailsPrefix = "/3/tv/";

    private readonly List<HttpRequestMessage> _requests = new();

    public IReadOnlyList<HttpRequestMessage> Requests
    {
        get { lock (_requests) return _requests.ToList(); }
    }

    /// <summary>Only the requests to TMDB's image host — what a logo fetch costs.</summary>
    public IReadOnlyList<HttpRequestMessage> ImageRequests =>
        Requests.Where(IsImageRequest).ToList();

    /// <summary>Only the requests for a series search — what one search costs.</summary>
    public IReadOnlyList<HttpRequestMessage> SeriesSearchRequests =>
        Requests.Where(request => PathOf(request) == SeriesSearchPath).ToList();

    /// <summary>Only the requests for one series' details — what opening one match costs.</summary>
    public IReadOnlyList<HttpRequestMessage> SeriesDetailsRequests =>
        Requests.Where(IsSeriesDetailsRequest).ToList();

    /// <summary>What the next provider fetch gets back. Replace to change the answer mid-test.</summary>
    public Func<HttpResponseMessage> RespondToProviders { get; set; } = () => Json(DefaultProviders);

    public void RespondToProvidersWith(string json) => RespondToProviders = () => Json(json);

    public void FailProviders() =>
        RespondToProviders = () => new HttpResponseMessage(HttpStatusCode.InternalServerError);

    /// <summary>What the next series search gets back.</summary>
    public Func<HttpResponseMessage> RespondToSeries { get; set; } = () => Json(DefaultSeries);

    public void RespondToSeriesWith(string json) => RespondToSeries = () => Json(json);

    public void FailSeries() =>
        RespondToSeries = () => new HttpResponseMessage(HttpStatusCode.InternalServerError);

    /// <summary>
    /// Makes the next series search time out — what a TMDB that accepts the connection and then
    /// says nothing costs, without a test having to wait out the real timeout. This is the
    /// exception <see cref="HttpClient"/> raises when its own timeout runs out.
    /// </summary>
    public void TimeOutOnSeries() => RespondToSeries = () => throw new TaskCanceledException();

    /// <summary>What the next details fetch gets back.</summary>
    public Func<HttpResponseMessage> RespondToDetails { get; set; } = () => Json(DefaultSeriesDetails);

    public void RespondToDetailsWith(string json) => RespondToDetails = () => Json(json);

    public void FailDetails() =>
        RespondToDetails = () => new HttpResponseMessage(HttpStatusCode.InternalServerError);

    /// <summary>What TMDB answers for an id it has never heard of.</summary>
    public void NotFoundOnDetails() =>
        RespondToDetails = () => new HttpResponseMessage(HttpStatusCode.NotFound);

    /// <summary>
    /// Makes the next details fetch time out — what a TMDB that accepts the connection and then
    /// says nothing costs, without a test having to wait out the real timeout.
    /// </summary>
    public void TimeOutOnDetails() => RespondToDetails = () => throw new TaskCanceledException();

    /// <summary>What the next logo fetch gets back.</summary>
    public Func<HttpResponseMessage> RespondToImages { get; set; } = () => Image(ImageBytes);

    public void FailImages() => RespondToImages = () => new HttpResponseMessage(HttpStatusCode.NotFound);

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        lock (_requests) _requests.Add(request);
        return Task.FromResult(AnswerTo(request)());
    }

    private Func<HttpResponseMessage> AnswerTo(HttpRequestMessage request)
    {
        if (IsImageRequest(request)) return RespondToImages;
        if (IsSeriesDetailsRequest(request)) return RespondToDetails;

        return PathOf(request) switch
        {
            WatchProvidersPath => RespondToProviders,
            SeriesSearchPath => RespondToSeries,
            _ => () => new HttpResponseMessage(HttpStatusCode.NotFound),
        };
    }

    private static string? PathOf(HttpRequestMessage request) => request.RequestUri?.AbsolutePath;

    private static bool IsSeriesDetailsRequest(HttpRequestMessage request) =>
        PathOf(request)?.StartsWith(SeriesDetailsPrefix, StringComparison.Ordinal) == true;

    private static bool IsImageRequest(HttpRequestMessage request) =>
        request.RequestUri?.Host == "image.tmdb.org";

    private static HttpResponseMessage Image(byte[] bytes)
    {
        var response = new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) };
        response.Content.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        return response;
    }

    /// <summary>A JPEG's first bytes and nothing more: the tests care that they come back whole.</summary>
    public static readonly byte[] ImageBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, (byte)'J', (byte)'F'];

    private static HttpResponseMessage Json(string body) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(body, Encoding.UTF8, "application/json"),
    };

    /// <summary>
    /// Shaped like TMDB's own answer, per-country priority map and provider ids included, so the
    /// tests can prove what the BFF keeps and what it throws away.
    /// </summary>
    public const string DefaultProviders = """
        {
          "results": [
            {
              "display_priority": 6,
              "logo_path": "/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg",
              "provider_name": "Netflix",
              "provider_id": 8,
              "display_priorities": { "AR": 25, "NO": 6, "US": 8 }
            },
            {
              "display_priority": 2,
              "logo_path": "/97yvRBw1GzX7fXprcF80er19ot.jpg",
              "provider_name": "Disney Plus",
              "provider_id": 337,
              "display_priorities": { "NO": 2, "US": 4 }
            },
            {
              "display_priority": 11,
              "logo_path": "/dQeAar5H991VYporEjUspolDarG.jpg",
              "provider_name": "Apple TV+",
              "provider_id": 350,
              "display_priorities": { "NO": 11 }
            },
            {
              "display_priority": 30,
              "logo_path": "/nEQAdEmJqAeanCkKKJUKAJKNEXW.jpg",
              "provider_name": "NRK TV",
              "provider_id": 383,
              "display_priorities": { "NO": 30 }
            }
          ]
        }
        """;

    /// <summary>
    /// Shaped like TMDB's own details answer, networks, ratings and a specials season included,
    /// so the tests can prove what the BFF keeps, what it throws away, and that season 0 comes
    /// through with the rest.
    /// </summary>
    public const string DefaultSeriesDetails = """
        {
          "adult": false,
          "backdrop_path": "/8NClAsRlpjUcOZoQPvomjTqhOhO.jpg",
          "created_by": [ { "id": 2467337, "name": "Dan Erickson" } ],
          "episode_run_time": [],
          "first_air_date": "2022-02-17",
          "genres": [ { "id": 18, "name": "Drama" } ],
          "homepage": "https://tv.apple.com/show/severance",
          "id": 95396,
          "in_production": true,
          "languages": ["en"],
          "last_air_date": "2025-03-21",
          "name": "Severance",
          "networks": [ { "id": 2552, "name": "Apple TV+" } ],
          "number_of_episodes": 19,
          "number_of_seasons": 2,
          "origin_country": ["US"],
          "original_language": "en",
          "original_name": "Severance (original)",
          "overview": "Mark leads a team of office workers whose memories have been surgically divided.",
          "popularity": 226.7,
          "poster_path": "/lFf6LLrQjYldcZItzOkGmMMigP7.jpg",
          "seasons": [
            {
              "air_date": "2022-04-01",
              "episode_count": 3,
              "id": 200000,
              "name": "Specials",
              "overview": "",
              "poster_path": "/specials.jpg",
              "season_number": 0,
              "vote_average": 0
            },
            {
              "air_date": "2022-02-17",
              "episode_count": 9,
              "id": 126137,
              "name": "Season 1",
              "overview": "",
              "poster_path": "/season1.jpg",
              "season_number": 1,
              "vote_average": 7.9
            },
            {
              "air_date": "2025-01-17",
              "episode_count": 10,
              "id": 396324,
              "name": "Season 2",
              "overview": "",
              "poster_path": "/season2.jpg",
              "season_number": 2,
              "vote_average": 8.1
            }
          ],
          "status": "Returning Series",
          "tagline": "Who are you at work?",
          "type": "Scripted",
          "vote_average": 8.4,
          "vote_count": 3106
        }
        """;

    /// <summary>
    /// Shaped like TMDB's own search answer, overviews, posters and paging included, so the tests
    /// can prove that a search answers with the id and the name and nothing else.
    /// </summary>
    public const string DefaultSeries = """
        {
          "page": 1,
          "results": [
            {
              "id": 95396,
              "name": "Severance",
              "original_name": "Severance",
              "original_language": "en",
              "overview": "Mark leads a team of office workers whose memories have been surgically divided.",
              "poster_path": "/lFf6LLrQjYldcZItzOkGmMMigP7.jpg",
              "backdrop_path": "/8NClAsRlpjUcOZoQPvomjTqhOhO.jpg",
              "first_air_date": "2022-02-17",
              "genre_ids": [18, 9648, 878],
              "origin_country": ["US"],
              "popularity": 226.7,
              "vote_average": 8.4,
              "vote_count": 3106,
              "adult": false
            },
            {
              "id": 1399,
              "name": "Game of Thrones",
              "original_name": "Game of Thrones",
              "original_language": "en",
              "overview": "Seven noble families fight for control of the mythical land of Westeros.",
              "poster_path": "/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
              "first_air_date": "2011-04-17",
              "vote_average": 8.4,
              "adult": false
            }
          ],
          "total_pages": 1,
          "total_results": 2
        }
        """;
}
