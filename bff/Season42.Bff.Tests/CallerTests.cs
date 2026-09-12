using System.Net;
using Microsoft.AspNetCore.Http;

namespace Season42.Bff.Tests;

/// <summary>
/// Which bucket a request is counted against (ADR-0017). Driven against a context rather than
/// through the server, because the fallback is the half a request through the test host cannot
/// reach: a TestServer connection has no remote address for it to fall back to, and a fallback
/// nothing exercises is a limit one rotated header escapes on any deployment without fly-proxy in
/// front of it.
/// </summary>
public class CallerTests
{
    [Fact]
    public void TheProxysWordIsTheCaller()
    {
        var context = new DefaultHttpContext();
        context.Request.Headers[RateLimiting.ClientIpHeader] = "203.0.113.7";
        context.Connection.RemoteIpAddress = IPAddress.Parse("10.0.0.1");

        // The connection is fly-proxy's own, so preferring it would put every caller in one bucket.
        Assert.Equal("203.0.113.7", RateLimiting.CallerOf(context));
    }

    [Fact]
    public void WithNoProxy_TheConnectionIsTheCaller()
    {
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = IPAddress.Parse("198.51.100.4");

        Assert.Equal("198.51.100.4", RateLimiting.CallerOf(context));
    }

    [Fact]
    public void AnEmptyHeaderFallsBackRatherThanBecomingABucketOfItsOwn()
    {
        var context = new DefaultHttpContext();
        context.Request.Headers[RateLimiting.ClientIpHeader] = "";
        context.Connection.RemoteIpAddress = IPAddress.Parse("198.51.100.4");

        Assert.Equal("198.51.100.4", RateLimiting.CallerOf(context));
    }

    [Fact]
    public void WithNeither_EveryCallerSharesOneBucket()
    {
        // Stricter than inventing a key each, which would be no limit at all.
        var context = new DefaultHttpContext();

        Assert.Equal(RateLimiting.CallerOf(context), RateLimiting.CallerOf(new DefaultHttpContext()));
        Assert.NotEqual("", RateLimiting.CallerOf(context));
    }
}
