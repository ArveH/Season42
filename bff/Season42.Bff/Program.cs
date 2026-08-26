using System.Text.Json;
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
builder.Services.AddHttpClient<TmdbSeriesSearch>(client => client.Timeout = tmdbTimeout);
builder.Services.AddSingleton<LogoStore>();
builder.Services.AddHttpClient<TmdbLogoImages>(client => client.Timeout = tmdbTimeout);
builder.Services.AddHostedService(services => services.GetRequiredService<WatchProviderRefresh>());

var app = builder.Build();

// A liveness probe and nothing more: it answers for the host, never for the snapshot. A replica
// with no snapshot is the only replica during a TMDB outage, and marking it unready there would
// turn a degraded service — one answering an honest 503 from /providers — into a dead one.
app.MapGet("/health", () => Results.Ok());

app.MapGet("/providers", (string? query, WatchProviderStore store) =>
{
    if (string.IsNullOrWhiteSpace(query))
    {
        return Results.Problem(
            "Give a search text: /providers?query=net.", statusCode: StatusCodes.Status400BadRequest);
    }

    var matches = store.Search(query);
    if (matches is null)
    {
        return Results.Problem(
            "No watch providers have been fetched from TMDB yet.",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    return Results.Ok(matches.Select(provider => new WatchProviderResult(provider.Name, provider.LogoPath)));
});

app.MapGet("/series", async (
    string? query, TmdbSeriesSearch tmdb, CancellationToken cancellationToken) =>
{
    if (string.IsNullOrWhiteSpace(query))
    {
        return Results.Problem(
            "Give a search text: /series?query=severance.", statusCode: StatusCodes.Status400BadRequest);
    }

    // Nothing is kept and nothing is consulted: unlike /providers, which answers from a snapshot
    // the server took hours ago, this asks TMDB every time. A search is one cheap call, and the
    // thing a user searches for is often the thing they only just heard of.
    try
    {
        return Results.Ok(await tmdb.SearchAsync(query, cancellationToken));
    }
    // TMDB refused, went quiet until the timeout ran out, or answered with something that is not
    // a search answer. All three are one thing to the user — the server behind this one did not
    // come up with an answer — and none of them is theirs to fix. A cancellation that is the
    // caller's own going away is deliberately not caught: nobody is left to tell.
    catch (Exception exception) when (
        exception is HttpRequestException or JsonException
        || (exception is OperationCanceledException && !cancellationToken.IsCancellationRequested))
    {
        app.Logger.LogWarning(exception, "TMDB could not be asked for series matching {Query}.", query);
        return Results.Problem(
            "TMDB could not be asked for series.", statusCode: StatusCodes.Status502BadGateway);
    }
});

app.MapGet("/logos/{file}", async (
    string file, WatchProviderStore providers, LogoStore logos, CancellationToken cancellationToken) =>
{
    // The snapshot is the allowlist, and it is consulted before anything touches the filesystem:
    // a path no Watch Provider publishes is not a path this server serves. Path traversal is
    // refused right here, by this same check, rather than by a rule of its own — there is nothing
    // to escape from when the only names that get through are ones TMDB gave us.
    switch (providers.Publishes(file))
    {
        case null:
            return Results.Problem(
                "No watch providers have been fetched from TMDB yet.",
                statusCode: StatusCodes.Status503ServiceUnavailable);
        case false:
            return Results.Problem(
                "No watch provider in the current snapshot has that logo.",
                statusCode: StatusCodes.Status404NotFound);
    }

    try
    {
        var bytes = await logos.ReadOrFetchAsync(file, cancellationToken);
        return Results.File(bytes, LogoStore.ContentTypeOf(file));
    }
    catch (HttpRequestException exception)
    {
        app.Logger.LogWarning(exception, "TMDB could not serve the logo {File}.", file);
        return Results.Problem(
            "TMDB could not be asked for that logo.", statusCode: StatusCodes.Status502BadGateway);
    }
});

app.Run();

/// <summary>What a search answers with: the name, and TMDB's logo path verbatim.</summary>
internal sealed record WatchProviderResult(string Name, string LogoPath);

public partial class Program;
