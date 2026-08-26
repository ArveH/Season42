namespace Season42.Bff;

/// <summary>
/// The one place that talks to TMDB's image host. It hands back an image's bytes; deciding
/// whether to ask at all belongs to the store that asked — <see cref="LogoStore"/> for a Watch
/// Provider's logo, <see cref="PosterStore"/> for a series' poster.
/// </summary>
/// <remarks>
/// The sizes live here together, one committed constant each, because a size is what the bytes
/// on disk are: changing one is not a migration but a deletion of that store's directory
/// (ADR-0008, ADR-0012). Neither is a parameter of the ask, so no caller can name a size.
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

    /// <summary>
    /// The bytes of one image, at one of the sizes above. No token goes with this: TMDB's image
    /// host is public, and the access token belongs only on the API calls that need it.
    /// </summary>
    /// <param name="size">One of the constants above, never anything a caller of this server said.</param>
    /// <param name="file">The file TMDB published it under, without its leading slash.</param>
    /// <exception cref="HttpRequestException">TMDB could not serve the image.</exception>
    public async Task<byte[]> FetchAsync(string size, string file, CancellationToken cancellationToken)
    {
        using var response = await http.GetAsync($"{ImageHost}/{size}/{file}", cancellationToken);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsByteArrayAsync(cancellationToken);
    }
}
