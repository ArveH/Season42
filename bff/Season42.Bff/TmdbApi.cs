using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// One ask of TMDB's API: the address it lives at, the token that authenticates it, and the
/// shape its answers come in. Every ask this server makes of the API goes through here, so that
/// what each one holds is its own path and its own reading of the answer, and nothing else.
/// </summary>
/// <remarks>
/// Not the image host: that is public, takes no token, and answers with bytes rather than JSON,
/// so <see cref="TmdbImages"/> talks to it directly. This is the API, and the API is the
/// half the token belongs to.
/// </remarks>
public sealed class TmdbApi(HttpClient http, IOptions<TmdbOptions> options)
{
    /// <summary>TMDB's v3 API. Every path below is relative to this.</summary>
    private const string BaseAddress = "https://api.themoviedb.org/3";

    /// <summary>TMDB writes its property names in snake case; this is what reads them.</summary>
    private static readonly JsonSerializerOptions TmdbFormat = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    /// <summary>
    /// Asks for <paramref name="path"/> and reads the answer as a <typeparamref name="T"/>.
    /// Anything but success is this server not having got an answer.
    /// </summary>
    /// <param name="path">Rooted, and relative to the API — <c>/search/tv?query=…</c>. Whatever
    /// of it came from the caller of this server is theirs to escape.</param>
    /// <exception cref="HttpRequestException">TMDB could not be reached, or refused.</exception>
    /// <exception cref="TaskCanceledException">TMDB said nothing before the client's timeout.</exception>
    /// <exception cref="JsonException">TMDB answered with something that is not a <typeparamref name="T"/>.</exception>
    public async Task<T> GetAsync<T>(string path, CancellationToken cancellationToken)
    {
        using var response = await SendAsync(path, cancellationToken);
        response.EnsureSuccessStatusCode();
        return await ReadAsync<T>(response, cancellationToken);
    }

    /// <summary>
    /// The same ask, where a <c>404</c> is an answer rather than a failure: null means TMDB has
    /// never heard of what was asked for. Only for asks that name one thing — a search that
    /// matched nothing is an empty list, not a 404.
    /// </summary>
    /// <inheritdoc cref="GetAsync{T}" path="/exception"/>
    public async Task<T?> GetIfFoundAsync<T>(string path, CancellationToken cancellationToken)
        where T : class
    {
        using var response = await SendAsync(path, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();
        return await ReadAsync<T>(response, cancellationToken);
    }

    private async Task<HttpResponseMessage> SendAsync(string path, CancellationToken cancellationToken)
    {
        // The token goes in the header. TMDB also accepts it as a query parameter, where it would
        // end up in every access log and proxy cache between here and there.
        using var request = new HttpRequestMessage(HttpMethod.Get, $"{BaseAddress}{path}");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", options.Value.AccessToken);

        // Awaited here rather than handed back as a task, so that the request outlives the send
        // it belongs to. The answer is read after this returns, which is safe because the client
        // buffers the body before it hands the response over.
        return await http.SendAsync(request, cancellationToken);
    }

    /// <summary>
    /// TMDB answering a bare <c>null</c> is not an answer to what was asked, and every caller
    /// would otherwise have to say so itself.
    /// </summary>
    private static async Task<T> ReadAsync<T>(
        HttpResponseMessage response, CancellationToken cancellationToken) =>
        await response.Content.ReadFromJsonAsync<T>(TmdbFormat, cancellationToken)
        ?? throw new JsonException($"TMDB answered with null where a {typeof(T).Name} was asked for.");
}
