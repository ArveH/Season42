using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Season42.Api;

namespace Season42.Api.Tests;

public class CatalogEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public CatalogEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetCatalog_ReturnsOkWithJsonContentType()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/catalog");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task GetCatalog_DeserializesIntoCatalogDto()
    {
        var catalog = await GetCatalogAsync();

        Assert.NotEmpty(catalog.StreamingServices);
        Assert.NotEmpty(catalog.Series);
        Assert.NotEmpty(catalog.Movies);
    }

    [Fact]
    public async Task GetCatalog_SeriesCarryExternalIdSeasonsAndDescription()
    {
        var catalog = await GetCatalogAsync();

        Assert.All(catalog.Series, series =>
        {
            Assert.False(string.IsNullOrWhiteSpace(series.ExternalId));
            Assert.False(string.IsNullOrWhiteSpace(series.Title));
            Assert.False(string.IsNullOrWhiteSpace(series.Description));
            Assert.NotEmpty(series.Seasons);
            Assert.All(series.Seasons, episodeCount => Assert.True(episodeCount > 0));
        });
    }

    [Fact]
    public async Task GetCatalog_MoviesCarryExternalIdAndDescription()
    {
        var catalog = await GetCatalogAsync();

        Assert.All(catalog.Movies, movie =>
        {
            Assert.False(string.IsNullOrWhiteSpace(movie.ExternalId));
            Assert.False(string.IsNullOrWhiteSpace(movie.Title));
            Assert.False(string.IsNullOrWhiteSpace(movie.Description));
        });
    }

    [Fact]
    public async Task GetCatalog_StreamingServicesCarryExternalIdAndName()
    {
        var catalog = await GetCatalogAsync();

        Assert.All(catalog.StreamingServices, service =>
        {
            Assert.False(string.IsNullOrWhiteSpace(service.ExternalId));
            Assert.False(string.IsNullOrWhiteSpace(service.Name));
        });
    }

    [Fact]
    public async Task GetCatalog_ServesTheBundledSnapshotByteForByte()
    {
        var client = _factory.CreateClient();

        var served = await client.GetByteArrayAsync("/catalog");
        var snapshotPath = Path.Combine(AppContext.BaseDirectory, "Data", "catalog.json");
        var bundled = await File.ReadAllBytesAsync(snapshotPath);

        Assert.Equal(bundled, served);
    }

    private async Task<CatalogDto> GetCatalogAsync()
    {
        var client = _factory.CreateClient();
        var json = await client.GetStringAsync("/catalog");
        var catalog = JsonSerializer.Deserialize<CatalogDto>(json, JsonOptions);
        Assert.NotNull(catalog);
        return catalog;
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };
}
