using System.Net;
using System.Net.Http.Json;

namespace Season42.Bff.Tests;

/// <summary>
/// The BFF is open to the internet and holds a token that is not, so a caller gets a share of it
/// rather than all of it (ADR-0017). Most of these leave the window at its deployed minute and cut
/// the permits to two or three, so spending a caller's share is a handful of requests rather than
/// sixty; the one that waits for the share to come back is the exception, and shortens the window
/// instead.
/// </summary>
public class RateLimitingTests
{
    /// <summary>A server whose window admits <paramref name="permits"/> requests and no more.</summary>
    private static BffFactory ServerAdmitting(int permits, FakeTmdb? tmdb = null)
    {
        var factory = new BffFactory(tmdb);
        factory.PermitsPerWindow = permits;
        return factory;
    }

    [Fact]
    public async Task WithinTheWindowsPermits_EverySearchIsAnswered()
    {
        using var factory = ServerAdmitting(3);
        var client = factory.CreateClient();

        var answers = new List<HttpStatusCode>();
        for (var ask = 0; ask < 3; ask++)
        {
            answers.Add((await client.GetAsync("/series?query=severance")).StatusCode);
        }

        Assert.All(answers, status => Assert.Equal(HttpStatusCode.OK, status));
    }

    [Fact]
    public async Task OnceThePermitsAreSpent_TheNextAskIsRefusedWith429()
    {
        using var factory = ServerAdmitting(2);
        var client = factory.CreateClient();

        await client.GetAsync("/series?query=severance");
        await client.GetAsync("/series?query=severance");
        var refused = await client.GetAsync("/series?query=severance");

        Assert.Equal(HttpStatusCode.TooManyRequests, refused.StatusCode);
    }

    [Fact]
    public async Task ARefusedAskSaysHowLongToWait()
    {
        using var factory = ServerAdmitting(1);
        var client = factory.CreateClient();

        await client.GetAsync("/series?query=severance");
        var refused = await client.GetAsync("/series?query=severance");

        // Without this a client has nothing to back off by but a guess, and the guess that costs
        // the server least is the one nobody makes.
        var retryAfter = Assert.Single(refused.Headers.GetValues("Retry-After"));
        Assert.True(int.Parse(retryAfter) > 0, $"Retry-After was {retryAfter}.");
    }

    [Fact]
    public async Task ARefusedAskExplainsItselfAsAProblem()
    {
        using var factory = ServerAdmitting(1);
        var client = factory.CreateClient();

        await client.GetAsync("/series?query=severance");
        var refused = await client.GetAsync("/series?query=severance");

        var problem = await refused.Content.ReadFromJsonAsync<ProblemBody>();
        Assert.Equal(429, problem?.Status);
        Assert.Contains("too many", problem?.Detail ?? "", StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task TheSpentPermitsAreOneCallersOwn_AndNotAnothers()
    {
        using var factory = ServerAdmitting(1);
        var client = factory.CreateClient();

        await AskAs(client, "203.0.113.7");
        var sameCaller = await AskAs(client, "203.0.113.7");
        var otherCaller = await AskAs(client, "198.51.100.4");

        Assert.Equal(HttpStatusCode.TooManyRequests, sameCaller.StatusCode);
        Assert.Equal(HttpStatusCode.OK, otherCaller.StatusCode);
    }

    [Fact]
    public async Task EveryTmdbBackedRouteIsBehindTheLimit()
    {
        // The point of the limit is the token, so a route that reaches TMDB and is not behind it
        // is a hole. This list is written by hand and nothing enumerates the app's endpoints, so a
        // route added to Program.cs and not added here is not caught here — what covers it is the
        // limiter being global with one exemption rather than an opt-in per route (ADR-0017). This
        // asserts that arrangement actually holds for every route there is today.
        string[] routes =
        [
            "/providers?query=net",
            "/series?query=severance",
            "/series/95396",
            "/series/95396/poster",
            "/movies?query=arrival",
            "/movies/329865",
            "/movies/329865/poster",
            "/logos/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg",
        ];

        foreach (var route in routes)
        {
            using var factory = ServerAdmitting(1);
            var client = factory.CreateClient();

            await client.GetAsync(route);
            var refused = await client.GetAsync(route);

            Assert.Equal(HttpStatusCode.TooManyRequests, refused.StatusCode);
        }
    }

    [Fact]
    public async Task HealthIsNeverRefused_BecauseTheProbeIsNotACaller()
    {
        using var factory = ServerAdmitting(1);
        var client = factory.CreateClient();

        // Spend the permits, then probe well past them: a 429 to Fly's health check is a machine
        // Fly restarts, which is an outage the limit would have caused rather than prevented.
        await client.GetAsync("/series?query=severance");
        await client.GetAsync("/series?query=severance");

        var probes = new List<HttpStatusCode>();
        for (var probe = 0; probe < 5; probe++)
        {
            probes.Add((await client.GetAsync("/health")).StatusCode);
        }

        Assert.All(probes, status => Assert.Equal(HttpStatusCode.OK, status));
    }

    [Fact]
    public async Task ABadAskStillCostsAPermit_BecauseTheCheapWayInIsNotAWayIn()
    {
        using var factory = ServerAdmitting(2);
        var client = factory.CreateClient();

        // A query-less /series never reaches TMDB, but it is still a request the server served.
        await client.GetAsync("/series");
        await client.GetAsync("/series");
        var refused = await client.GetAsync("/series?query=severance");

        Assert.Equal(HttpStatusCode.TooManyRequests, refused.StatusCode);
    }

    [Fact]
    public async Task WhenTheWindowHasPassed_TheShareComesBack()
    {
        // The whole of the difference between a rate limit and a ban after sixty requests, and the
        // one thing here worth waiting real time for.
        var factory = new BffFactory();
        factory.PermitsPerWindow = 1;
        factory.WindowSeconds = 1;
        using var _ = factory;
        var client = factory.CreateClient();

        await client.GetAsync("/series?query=severance");
        var refused = await client.GetAsync("/series?query=severance");
        await Task.Delay(TimeSpan.FromSeconds(1.5));
        var afterTheWindow = await client.GetAsync("/series?query=severance");

        Assert.Equal(HttpStatusCode.TooManyRequests, refused.StatusCode);
        Assert.Equal(HttpStatusCode.OK, afterTheWindow.StatusCode);
    }

    [Fact]
    public void AStartupLimitOfNothingIsRefused_RatherThanA500PerRoute()
    {
        // The same bargain Program.cs strikes over the TMDB token: a server that cannot serve is
        // better off saying so while starting than while answering.
        using var factory = new BffFactory();
        factory.PermitsPerWindow = 0;

        var failure = Record.Exception(() => factory.CreateClient());

        Assert.NotNull(failure);
        Assert.Contains(nameof(RateLimitOptions.PermitsPerWindow), failure.ToString());
    }

    private static Task<HttpResponseMessage> AskAs(HttpClient client, string clientIp)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, "/series?query=severance");
        request.Headers.Add(RateLimiting.ClientIpHeader, clientIp);
        return client.SendAsync(request);
    }

    private sealed record ProblemBody(int? Status, string? Detail);
}
