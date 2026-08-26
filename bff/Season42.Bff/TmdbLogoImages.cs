namespace Season42.Bff;

/// <summary>
/// The one place that talks to TMDB's image host. It hands back a logo's bytes; deciding whether
/// to ask at all belongs to <see cref="LogoStore"/>.
/// </summary>
public sealed class TmdbLogoImages(HttpClient http)
{
    private const string ImageHost = "https://image.tmdb.org/t/p";

    /// <summary>The size rows draw logos at — 16–24pt — with room to stay sharp on a 3x screen.</summary>
    public const string Size = "w154";

    /// <summary>
    /// The bytes of one logo. No token goes with this: TMDB's image host is public, and the
    /// access token belongs only on the API calls that need it.
    /// </summary>
    public async Task<byte[]> FetchAsync(string file, CancellationToken cancellationToken)
    {
        using var response = await http.GetAsync($"{ImageHost}/{Size}/{file}", cancellationToken);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsByteArrayAsync(cancellationToken);
    }
}
