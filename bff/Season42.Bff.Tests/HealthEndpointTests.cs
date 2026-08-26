using System.Net;

namespace Season42.Bff.Tests;

/// <summary>
/// <c>/health</c> is a liveness probe and nothing more: it answers for the host, not for the
/// snapshot. A replica with no snapshot is the only replica during a TMDB outage, and one that
/// reported itself unhealthy there would turn a degraded service — one answering an honest
/// <c>503</c> from <c>/providers</c> — into a dead one.
/// </summary>
public class HealthEndpointTests
{
    [Fact]
    public async Task Health_IsOkOnceTheHostHasStarted()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Health_IsOkWithNoSnapshot_WhileProvidersSaysSoHonestly()
    {
        var unreachable = new FakeTmdb();
        unreachable.Fail();
        using var factory = new BffFactory(unreachable);
        var client = factory.CreateClient();

        var health = await client.GetAsync("/health");
        var providers = await client.GetAsync("/providers?search=net");

        Assert.Equal(HttpStatusCode.OK, health.StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, providers.StatusCode);
    }

    [Fact]
    public async Task Health_SaysNothingAboutTheSnapshot()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var body = await client.GetStringAsync("/health");

        Assert.DoesNotContain("Netflix", body);
        Assert.DoesNotContain("snapshot", body, StringComparison.OrdinalIgnoreCase);
    }
}
