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
// One client for the whole API, because one ask of it is what every one of these is built on;
// the image host keeps its own, being a different host that takes no token.
builder.Services.AddHttpClient<TmdbApi>(client => client.Timeout = tmdbTimeout);
builder.Services.AddTransient<TmdbWatchProviders>();
builder.Services.AddTransient<TmdbSeriesSearch>();
builder.Services.AddTransient<TmdbSeriesDetails>();
builder.Services.AddTransient<TmdbMovieSearch>();
builder.Services.AddTransient<TmdbMovieDetails>();
builder.Services.AddSingleton<WatchProviderRefresh>();
builder.Services.AddSingleton<LogoStore>();
builder.Services.AddSingleton<PosterStore>();
builder.Services.AddHttpClient<TmdbImages>(client => client.Timeout = tmdbTimeout);
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
    catch (Exception exception) when (TmdbFailed(exception, cancellationToken))
    {
        app.Logger.LogWarning(exception, "TMDB could not be asked for series matching {Query}.", query);
        return Results.Problem(
            "TMDB could not be asked for series.", statusCode: StatusCodes.Status502BadGateway);
    }
});

// One series, by the id a Series Match carried. Nothing is kept here either: a series that has
// just gained a season is exactly the one a user is likely to be looking at. The route reads an
// int, so anything that is not an id never reaches TMDB at all — asking by name is what the
// search beside this is for.
app.MapGet("/series/{id:int}", async (
    int id, TmdbSeriesDetails tmdb, CancellationToken cancellationToken) =>
{
    try
    {
        var details = await tmdb.DetailsOfAsync(id, cancellationToken);

        // An id TMDB has never heard of is the caller asking about something that isn't there,
        // which is a different answer from an ask this server could not make at all.
        return details is null
            ? Results.Problem(
                "TMDB knows no series with that id.", statusCode: StatusCodes.Status404NotFound)
            : Results.Ok(details);
    }
    catch (Exception exception) when (TmdbFailed(exception, cancellationToken))
    {
        app.Logger.LogWarning(exception, "TMDB could not be asked about the series {Id}.", id);
        return Results.Problem(
            "TMDB could not be asked for series.", statusCode: StatusCodes.Status502BadGateway);
    }
});

// One series' poster, by the same id its details were read with — never by a path, because the
// app has none to send. That is the whole of this route's validation: the route reads an int, so
// nothing a caller says ever becomes part of a filesystem path. The logo route beside it is safe
// by a different mechanism, the snapshot as an allowlist, and there is no snapshot of posters for
// that mechanism to reach here (ADR-0012).
app.MapGet("/series/{id:int}/poster", async (
    int id, PosterStore posters, CancellationToken cancellationToken) =>
{
    try
    {
        var bytes = await posters.ReadOrFetchAsync(PosterSubject.Series, id, cancellationToken);

        // TMDB listing no poster and TMDB never having heard of the id are one answer here: there
        // is no poster to be had. The details the app already read say which of the two it is,
        // and say it before the app asks at all.
        return bytes is null
            ? Results.Problem(
                "TMDB has no poster for that series.", statusCode: StatusCodes.Status404NotFound)
            : Results.File(bytes, PosterStore.ContentType);
    }
    catch (Exception exception) when (TmdbFailed(exception, cancellationToken))
    {
        app.Logger.LogWarning(exception, "TMDB could not serve the poster of the series {Id}.", id);
        return Results.Problem(
            "TMDB could not be asked for that poster.", statusCode: StatusCodes.Status502BadGateway);
    }
});

// The same two asks as the series routes above, for a movie. Nothing is kept here either, and
// nothing about a movie is flattened on the way through: a movie is one thing to watch, so the
// seasons — and the inventing the app has to own up to about them — have no counterpart here.
app.MapGet("/movies", async (
    string? query, TmdbMovieSearch tmdb, CancellationToken cancellationToken) =>
{
    if (string.IsNullOrWhiteSpace(query))
    {
        return Results.Problem(
            "Give a search text: /movies?query=arrival.", statusCode: StatusCodes.Status400BadRequest);
    }

    try
    {
        return Results.Ok(await tmdb.SearchAsync(query, cancellationToken));
    }
    catch (Exception exception) when (TmdbFailed(exception, cancellationToken))
    {
        app.Logger.LogWarning(exception, "TMDB could not be asked for movies matching {Query}.", query);
        return Results.Problem(
            "TMDB could not be asked for movies.", statusCode: StatusCodes.Status502BadGateway);
    }
});

// One movie, by the id a Movie Match carried. The route reads an int, so anything that is not an
// id never reaches TMDB at all — asking by title is what the search beside this is for.
app.MapGet("/movies/{id:int}", async (
    int id, TmdbMovieDetails tmdb, CancellationToken cancellationToken) =>
{
    try
    {
        var details = await tmdb.DetailsOfAsync(id, cancellationToken);

        // An id TMDB has never heard of is the caller asking about something that isn't there,
        // which is a different answer from an ask this server could not make at all.
        return details is null
            ? Results.Problem(
                "TMDB knows no movie with that id.", statusCode: StatusCodes.Status404NotFound)
            : Results.Ok(details);
    }
    catch (Exception exception) when (TmdbFailed(exception, cancellationToken))
    {
        app.Logger.LogWarning(exception, "TMDB could not be asked about the movie {Id}.", id);
        return Results.Problem(
            "TMDB could not be asked for movies.", statusCode: StatusCodes.Status502BadGateway);
    }
});

// One movie's poster, on the same terms as a series' above and out of the same store: by the id
// its details were read with, never by a path, so the route reading an int is the whole of its
// validation. The store keeps the two apart by which kind of thing was asked about, because TMDB
// numbers its movies and its series separately (ADR-0012).
app.MapGet("/movies/{id:int}/poster", async (
    int id, PosterStore posters, CancellationToken cancellationToken) =>
{
    try
    {
        var bytes = await posters.ReadOrFetchAsync(PosterSubject.Movie, id, cancellationToken);

        // TMDB listing no poster and TMDB never having heard of the id are one answer here: there
        // is no poster to be had. The details the app already read say which of the two it is,
        // and say it before the app asks at all.
        return bytes is null
            ? Results.Problem(
                "TMDB has no poster for that movie.", statusCode: StatusCodes.Status404NotFound)
            : Results.File(bytes, PosterStore.ContentType);
    }
    catch (Exception exception) when (TmdbFailed(exception, cancellationToken))
    {
        app.Logger.LogWarning(exception, "TMDB could not serve the poster of the movie {Id}.", id);
        return Results.Problem(
            "TMDB could not be asked for that poster.", statusCode: StatusCodes.Status502BadGateway);
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

// TMDB refused, went quiet until the timeout ran out, or answered with something that is not an
// answer to what was asked. All three are one thing to the user — the server behind this one did
// not come up with an answer — and none of them is theirs to fix. A cancellation that is the
// caller's own going away is deliberately not one of them: nobody is left to tell.
static bool TmdbFailed(Exception exception, CancellationToken callerWentAway) =>
    exception is HttpRequestException or JsonException
    || (exception is OperationCanceledException && !callerWentAway.IsCancellationRequested);

/// <summary>What a search answers with: the name, and TMDB's logo path verbatim.</summary>
internal sealed record WatchProviderResult(string Name, string LogoPath);

public partial class Program;
