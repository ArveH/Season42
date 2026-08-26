using System.Net;
using System.Text.Json;

namespace Season42.Bff.Tests;

public class ProvidersEndpointTests
{
    [Fact]
    public async Task Search_MatchesNamesCaseInsensitivelyBySubstring()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var results = await SearchAsync(client, "net");

        Assert.Equal(["Netflix"], results.Select(result => result.Name));
    }

    [Fact]
    public async Task Search_MatchesInsideTheName_NotOnlyAtTheStart()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var results = await SearchAsync(client, "TV");

        Assert.Equal(["Apple TV+", "NRK TV"], results.Select(result => result.Name));
    }

    [Fact]
    public async Task Search_CarriesTmdbsLogoPathVerbatim()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var results = await SearchAsync(client, "netflix");

        Assert.Equal("/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg", Assert.Single(results).LogoPath);
    }

    [Fact]
    public async Task Search_MatchingNothing_IsAnEmptyArray()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/providers?search=nosuchservice");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Empty(await ReadAsync(response));
    }

    [Fact]
    public async Task Search_Blank_IsABadRequest()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/providers?search=")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/providers?search=%20%20")).StatusCode);
    }

    [Fact]
    public async Task Search_Missing_IsABadRequest()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/providers");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Search_BeforeAnySuccessfulFetch_IsUnavailable()
    {
        var tmdb = new FakeTmdb();
        tmdb.Fail();
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var response = await client.GetAsync("/providers?search=net");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task Search_CapsResultsAtTwenty()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondWith(PayloadOf(Enumerable.Range(1, 25)
            .Select(index => ($"Service {index:00}", index))));
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var results = await SearchAsync(client, "service");

        Assert.Equal(20, results.Count);
        Assert.Equal("Service 01", results[0].Name);
        Assert.Equal("Service 20", results[19].Name);
    }

    [Fact]
    public async Task Search_OrdersMatchesByDisplayPriority()
    {
        var tmdb = new FakeTmdb();
        tmdb.RespondWith(PayloadOf([("Zeta", 1), ("Alpha", 9), ("Mandalay", 5)]));
        using var factory = new BffFactory(tmdb);
        var client = factory.CreateClient();

        var results = await SearchAsync(client, "a");

        Assert.Equal(["Zeta", "Mandalay", "Alpha"], results.Select(result => result.Name));
    }

    internal static string PayloadOf(IEnumerable<(string Name, int Priority)> providers)
    {
        var results = providers.Select(provider => new
        {
            display_priority = provider.Priority,
            logo_path = $"/{provider.Name.Replace(' ', '-')}.jpg",
            provider_name = provider.Name,
            provider_id = 1000 + provider.Priority,
            display_priorities = new Dictionary<string, int> { ["NO"] = provider.Priority },
        });
        return JsonSerializer.Serialize(new { results });
    }

    internal static async Task<IReadOnlyList<ProviderResult>> SearchAsync(HttpClient client, string search)
    {
        var response = await client.GetAsync($"/providers?search={Uri.EscapeDataString(search)}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return await ReadAsync(response);
    }

    private static async Task<IReadOnlyList<ProviderResult>> ReadAsync(HttpResponseMessage response)
    {
        var json = await response.Content.ReadAsStringAsync();
        var results = JsonSerializer.Deserialize<List<ProviderResult>>(json, JsonOptions);
        Assert.NotNull(results);
        return results;
    }

    internal static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    internal sealed record ProviderResult(string Name, string LogoPath);
}
