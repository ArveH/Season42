using System.Net;

namespace Season42.Bff.Tests;

/// <summary><c>/health</c> answers for the host, never for the snapshot (ADR-0010).</summary>
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
    public async Task Health_AnswersWithNoBodyAtAll()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var body = await client.GetStringAsync("/health");

        // Nothing to report is the contract, not an omission: a probe body read by nothing is a
        // body that drifts, and snapshot age is its own endpoint if it is ever wanted (ADR-0010).
        Assert.Equal("", body);
    }
}
