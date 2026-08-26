namespace Season42.Bff;

/// <summary>
/// The one place that talks to TMDB's image host. It hands back an image's bytes; deciding
/// whether to ask at all belongs to the store that asked — <see cref="LogoStore"/> for a Watch
/// Provider's logo, <see cref="PosterStore"/> for a series' poster.
/// </summary>
/// <remarks>
/// The sizes live here together, one committed constant each, because a size is what the bytes
/// on disk are: changing one is not a migration but a deletion of that store's directory
/// (ADR-0008, ADR-0012). Each kind of image has its own ask at its own size, so a size is never
/// something a caller passes and never something a caller of this server could name.
/// </remarks>
public sealed class TmdbImages(HttpClient http)
{
    private const string ImageHost = "https://image.tmdb.org/t/p";

    /// <summary>The size rows draw logos at — 16–24pt — with room to stay sharp on a 3x screen.</summary>
    public const string LogoSize = "w154";

    /// <summary>
    /// The size posters are drawn at — a row's thumbnail beside the title, and the same bytes
    /// again on the detail screen above it. What the user looks at is what they keep.
    /// </summary>
    public const string PosterSize = "w342";

    /// <summary>The bytes of one Watch Provider's logo, at <see cref="LogoSize"/>.</summary>
    /// <param name="file">The file TMDB published it under, without its leading slash.</param>
    /// <inheritdoc cref="FetchAsync" path="/exception"/>
    public Task<byte[]> FetchLogoAsync(string file, CancellationToken cancellationToken) =>
        FetchAsync(LogoSize, file, cancellationToken);

    /// <summary>The bytes of one series' poster, at <see cref="PosterSize"/>.</summary>
    /// <param name="path">TMDB's poster path, leading slash and all.</param>
    /// <inheritdoc cref="FetchAsync" path="/exception"/>
    public Task<byte[]> FetchPosterAsync(string path, CancellationToken cancellationToken) =>
        FetchAsync(PosterSize, path.TrimStart('/'), cancellationToken);

    /// <summary>
    /// The bytes of one image. No token goes with this: TMDB's image host is public, and the
    /// access token belongs only on the API calls that need it.
    /// </summary>
    /// <exception cref="HttpRequestException">TMDB could not serve the image.</exception>
    private async Task<byte[]> FetchAsync(string size, string file, CancellationToken cancellationToken)
    {
        using var response = await http.GetAsync($"{ImageHost}/{size}/{file}", cancellationToken);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsByteArrayAsync(cancellationToken);
    }
}
