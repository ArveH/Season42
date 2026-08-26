using Season42.Bff;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOptions<TmdbOptions>()
    .Bind(builder.Configuration.GetSection(TmdbOptions.SectionName));

// A missing token is a startup failure. The alternative is a server that starts, looks healthy,
// and answers every search with the same unexplained emptiness.
if (string.IsNullOrWhiteSpace(builder.Configuration[TmdbOptions.AccessTokenKey]))
{
    throw new InvalidOperationException(
        $"No TMDB access token. Set {TmdbOptions.AccessTokenKey} — in development: dotnet user-secrets " +
        $"set \"{TmdbOptions.AccessTokenKey}\" \"<your TMDB API Read Access Token>\".");
}

builder.Services.AddSingleton<WatchProviderStore>();
var tmdbTimeout = TimeSpan.FromSeconds(15);
// A bounded timeout, because the first fetch is awaited as the server starts: without one, a
// TMDB that accepts the connection and then says nothing would hold the port shut for 100 seconds.
builder.Services.AddHttpClient<TmdbWatchProviders>(client => client.Timeout = tmdbTimeout);
builder.Services.AddSingleton<WatchProviderRefresh>();
builder.Services.AddHostedService(services => services.GetRequiredService<WatchProviderRefresh>());

var app = builder.Build();

app.MapGet("/providers", (string? search, WatchProviderStore store) =>
{
    if (string.IsNullOrWhiteSpace(search))
    {
        return Results.Problem(
            "Give a search text: /providers?search=net.", statusCode: StatusCodes.Status400BadRequest);
    }

    var matches = store.Search(search);
    if (matches is null)
    {
        return Results.Problem(
            "No watch providers have been fetched from TMDB yet.",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    return Results.Ok(matches.Select(provider => new WatchProviderResult(provider.Name, provider.LogoPath)));
});

app.Run();

/// <summary>What a search answers with: the name, and TMDB's logo path verbatim.</summary>
internal sealed record WatchProviderResult(string Name, string LogoPath);

public partial class Program;
