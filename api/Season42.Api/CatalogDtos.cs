namespace Season42.Api;

// Shape of the Catalog served by GET /catalog. ExternalId and PosterUrl exist so a
// future real data source (TMDB-like) can slot in without reshaping the app (ADR-0002).
public record CatalogDto(
    List<StreamingServiceDto> StreamingServices,
    List<CatalogSeriesDto> Series,
    List<CatalogMovieDto> Movies);

public record StreamingServiceDto(string ExternalId, string Name);

// Seasons holds the episode count of each season, in order.
public record CatalogSeriesDto(
    string ExternalId,
    string Title,
    string Description,
    string? PosterUrl,
    List<int> Seasons);

public record CatalogMovieDto(
    string ExternalId,
    string Title,
    string Description,
    string? PosterUrl);
