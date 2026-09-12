using System.Globalization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// The limit that lets this server be a public address without being a public TMDB token.
///
/// Every route that can reach TMDB is behind it; <c>/health</c> alone is not, because refusing
/// Fly's probe is an outage the limit would have caused rather than prevented. The bucket is the
/// caller's, so one script cannot spend everyone's share — and the price of that is that many
/// callers at once are many buckets, which this does not defend against and does not claim to
/// (ADR-0017).
/// </summary>
public static class RateLimiting
{
    /// <summary>
    /// The header fly-proxy puts the real client's address in. It cannot be spoofed from outside:
    /// the proxy overwrites whatever a caller sent, so a request that arrives with one carries the
    /// proxy's word rather than the caller's. Without the proxy — a local <c>dotnet run</c>, or the
    /// test host — there is no header and the connection's own address is the caller.
    /// </summary>
    public const string ClientIpHeader = "Fly-Client-IP";

    /// <summary>The one route that is not behind the limit.</summary>
    private const string Unlimited = "/health";

    /// <summary>
    /// The partition <see cref="Unlimited"/> falls in. A partitioned limiter builds one limiter
    /// per key and keeps it, so this key must be one no caller's key can also be: sharing a key
    /// with a caller would hand whichever arrived first to both, and the probe would inherit a
    /// limit or a caller would escape one. The `caller:` prefix below is the other half of that.
    /// </summary>
    private const string UnlimitedPartition = "unlimited";

    /// <summary>
    /// The key every caller with no address at all shares. A connection with no remote address is
    /// the test host or a local pipe; lumping them together is stricter than inventing a key each,
    /// which would be no limit at all.
    /// </summary>
    private const string UnknownCaller = "unknown";

    /// <summary>
    /// Wires the limit into the server. The parameter is named <c>host</c> rather than
    /// <c>builder</c> because Program.cs is top-level statements, whose own <c>builder</c> local is
    /// in scope for every type in this compilation and cannot be shadowed.
    /// </summary>
    public static void AddTo(WebApplicationBuilder host)
    {
        // Validated at startup rather than on the first request, for the reason Program.cs gives
        // about the TMDB token: a nonsense limit would otherwise surface as a 500 from every route
        // on a server that had started and looked healthy. A limiter cannot be built from a window
        // of zero seconds or a permit count below one, so those are a refusal to start.
        host.Services.AddOptions<RateLimitOptions>()
            .Bind(host.Configuration.GetSection(RateLimitOptions.SectionName))
            .Validate(
                options => options.PermitsPerWindow >= 1,
                $"{RateLimitOptions.SectionName}:{nameof(RateLimitOptions.PermitsPerWindow)} must be at least 1.")
            .Validate(
                options => options.WindowSeconds >= 1,
                $"{RateLimitOptions.SectionName}:{nameof(RateLimitOptions.WindowSeconds)} must be at least 1 second.")
            .ValidateOnStart();

        host.Services.AddRateLimiter(limiter =>
        {
            // OnRejected below writes the whole response, status included, so this is the
            // answer a caller gets only if that is ever removed. Stated rather than left at
            // the framework's 503, which would be this server claiming to be the one at fault.
            limiter.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            limiter.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
            {
                if (context.Request.Path.StartsWithSegments(Unlimited))
                {
                    return RateLimitPartition.GetNoLimiter(UnlimitedPartition);
                }

                // Read off the request rather than captured when this was wired, because a test
                // sets these through the host's own settings and a captured value would be the
                // default it replaced.
                var options = LimitsFor(context);

                return RateLimitPartition.GetFixedWindowLimiter($"caller:{CallerOf(context)}", _ =>
                    new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = options.PermitsPerWindow,
                        Window = options.Window,
                        // Nothing waits. A queued search is a search whose answer arrives after the
                        // user has given up, and a queue on a machine that stops when nobody is
                        // searching is memory held for exactly the caller it should not be held for.
                        QueueLimit = 0,
                    });
            });

            limiter.OnRejected = async (context, cancellationToken) =>
            {
                var window = LimitsFor(context.HttpContext).Window;

                // The limiter knows when the next permit falls due; the window is the fallback for
                // a limiter that does not say. Either way the caller is told rather than left to
                // guess, because the guess that costs this server least is the one nobody makes.
                var retryAfter = context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var due)
                    ? due
                    : window;

                context.HttpContext.Response.Headers.RetryAfter =
                    ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString(CultureInfo.InvariantCulture);

                await Results
                    .Problem(
                        "Too many requests. This is a personal server with one TMDB token behind " +
                        "it; wait for the Retry-After and ask again.",
                        statusCode: StatusCodes.Status429TooManyRequests)
                    .ExecuteAsync(context.HttpContext);
            };
        });
    }

    /// <summary>What this server is willing to serve one caller, as the running host has it.</summary>
    private static RateLimitOptions LimitsFor(HttpContext context) =>
        context.RequestServices.GetRequiredService<IOptions<RateLimitOptions>>().Value;

    /// <summary>
    /// Who is asking: fly-proxy's word where there is one, the connection's own address where
    /// there is not, and one shared bucket where there is neither. Public because the fallback is
    /// the half of this that no request through the test host can reach — a TestServer connection
    /// has no remote address to fall back to — and an untested fallback on a deployment without a
    /// proxy in front of it is a limit one header rotation escapes.
    /// </summary>
    public static string CallerOf(HttpContext context)
    {
        if (context.Request.Headers.TryGetValue(ClientIpHeader, out var forwarded))
        {
            var address = forwarded.ToString();
            if (!string.IsNullOrWhiteSpace(address)) return address;
        }

        return context.Connection.RemoteIpAddress?.ToString() ?? UnknownCaller;
    }
}
