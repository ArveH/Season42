using System.Net;

namespace Season42.Bff.Tests;

/// <summary>
/// Nothing fetched from TMDB is kept past the six-month clause in TMDB's terms. The two halves of
/// that are tested here together because they are one rule: an aged image is never served, and an
/// aged image nobody asks for again is not kept either (ADR-0020).
/// </summary>
public class EvictionTests
{
    /// <summary>The logo file of the Netflix row in <see cref="FakeTmdb.DefaultProviders"/>.</summary>
    private const string KnownLogo = "pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg";

    /// <summary>The id of Severance in <see cref="FakeTmdb.DefaultSeriesDetails"/>.</summary>
    private const int KnownSeries = 95396;

    /// <summary>The id of Arrival in <see cref="FakeTmdb.DefaultMovieDetails"/>.</summary>
    private const int KnownMovie = 329865;

    /// <summary>Backdates a stored file to when it would have been fetched, which is all age is.</summary>
    private static void Age(string path, TimeSpan by) =>
        File.SetLastWriteTimeUtc(path, DateTime.UtcNow - by);

    private static readonly TimeSpan PastTheLimit = StoreLifetime.Limit + TimeSpan.FromDays(1);
    private static readonly TimeSpan InsideTheLimit = StoreLifetime.Limit - TimeSpan.FromDays(1);

    [Fact]
    public async Task Logo_AgedPastTheLimit_IsFetchedAgainRatherThanServed()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        await client.GetAsync($"/logos/{KnownLogo}");
        Age(factory.LogoPathOf(KnownLogo), PastTheLimit);

        var response = await client.GetAsync($"/logos/{KnownLogo}");

        // Transparent to whoever asked: the same bytes, and a fetch they never hear about.
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(FakeTmdb.ImageBytes, await response.Content.ReadAsByteArrayAsync());
        Assert.Equal(2, factory.Tmdb.ImageRequests.Count);
    }

    [Fact]
    public async Task Logo_InsideTheLimit_IsStillServedFromTheStore()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        await client.GetAsync($"/logos/{KnownLogo}");
        Age(factory.LogoPathOf(KnownLogo), InsideTheLimit);

        var response = await client.GetAsync($"/logos/{KnownLogo}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Single(factory.Tmdb.ImageRequests);
    }

    [Fact]
    public async Task Poster_AgedPastTheLimit_IsFetchedAgainRatherThanServed()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        await client.GetAsync($"/series/{KnownSeries}/poster");
        Age(factory.PosterPathOf(PosterSubject.Series, KnownSeries), PastTheLimit);

        var response = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(FakeTmdb.ImageBytes, await response.Content.ReadAsByteArrayAsync());
        // A miss pays twice, as any other miss does: the details, then the image.
        Assert.Equal(2, factory.Tmdb.SeriesDetailsRequests.Count);
        Assert.Equal(2, factory.Tmdb.ImageRequests.Count);
    }

    [Fact]
    public async Task Poster_InsideTheLimit_IsStillServedFromTheStore()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        await client.GetAsync($"/series/{KnownSeries}/poster");
        Age(factory.PosterPathOf(PosterSubject.Series, KnownSeries), InsideTheLimit);

        var response = await client.GetAsync($"/series/{KnownSeries}/poster");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Single(factory.Tmdb.ImageRequests);
    }

    /// <summary>
    /// An aged image is gone whether or not the fetch that would have replaced it works. Serving
    /// it while TMDB is down would be keeping it past the limit for exactly as long as the outage
    /// lasts, which is not this server's to decide.
    /// </summary>
    [Fact]
    public async Task Logo_AgedPastTheLimit_IsDroppedEvenWhenTmdbCannotReplaceIt()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        await client.GetAsync($"/logos/{KnownLogo}");
        Age(factory.LogoPathOf(KnownLogo), PastTheLimit);
        factory.Tmdb.FailImages();

        var response = await client.GetAsync($"/logos/{KnownLogo}");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        Assert.False(File.Exists(factory.LogoPathOf(KnownLogo)));
    }

    [Fact]
    public async Task Sweep_RemovesAgedImagesFromBothStores_AndKeepsTheRest()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        await client.GetAsync($"/logos/{KnownLogo}");
        await client.GetAsync($"/series/{KnownSeries}/poster");
        Age(factory.LogoPathOf(KnownLogo), PastTheLimit);

        factory.Sweep();

        Assert.False(File.Exists(factory.LogoPathOf(KnownLogo)));
        Assert.True(File.Exists(factory.PosterPathOf(PosterSubject.Series, KnownSeries)));
    }

    /// <summary>
    /// An aged poster is swept out of its own half of the store, subject folders and all — the
    /// sweep walks what the stores wrote rather than only their top level.
    /// </summary>
    [Fact]
    public async Task Sweep_ReachesAPosterUnderItsSubjectFolder()
    {
        using var factory = new BffFactory();
        await factory.CreateClient().GetAsync($"/movies/{KnownMovie}/poster");
        Age(factory.PosterPathOf(PosterSubject.Movie, KnownMovie), PastTheLimit);

        factory.Sweep();

        Assert.False(File.Exists(factory.PosterPathOf(PosterSubject.Movie, KnownMovie)));
    }

    /// <summary>
    /// The sweep runs as the server starts, so a machine that was off for the six months is a
    /// machine that evicts the moment it is back rather than one that waits a day first. It is
    /// not waited for on the way up, so what this watches for is the file going rather than a
    /// server that has finished starting.
    /// </summary>
    [Fact]
    public async Task Sweep_RunsAtStartup_SoTimeSpentStoppedStillCounts()
    {
        var storePath = BffFactory.NewStoreDirectory();

        using (var first = new BffFactory(storePath: storePath))
        {
            await first.CreateClient().GetAsync($"/logos/{KnownLogo}");
            Age(first.LogoPathOf(KnownLogo), PastTheLimit);
        }

        using var restarted = new BffFactory(storePath: storePath);
        restarted.CreateClient();

        await WaitForAsync(() => !File.Exists(restarted.LogoPathOf(KnownLogo)));
    }

    /// <summary>
    /// Waits for the sweep that startup began. Fails rather than hanging the suite, and rather
    /// than passing on a file that was never there.
    /// </summary>
    private static async Task WaitForAsync(Func<bool> swept)
    {
        for (var attempt = 0; attempt < 500; attempt++)
        {
            if (swept()) return;
            await Task.Delay(10);
        }

        throw new TimeoutException("The sweep did not do what the test was waiting for.");
    }

    /// <summary>
    /// Nothing the sweep does is visible to a caller: the next ask fetches the image again and
    /// answers with it, which is what an image nobody owns costs.
    /// </summary>
    [Fact]
    public async Task Sweep_CostsOnlyAFetch_AndTheNextAskIsAnsweredAsBefore()
    {
        using var factory = new BffFactory();
        var client = factory.CreateClient();
        await client.GetAsync($"/logos/{KnownLogo}");
        Age(factory.LogoPathOf(KnownLogo), PastTheLimit);
        factory.Sweep();

        var response = await client.GetAsync($"/logos/{KnownLogo}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(FakeTmdb.ImageBytes, await response.Content.ReadAsByteArrayAsync());
        Assert.True(File.Exists(factory.LogoPathOf(KnownLogo)));
    }

    /// <summary>The snapshot is not an image and is refreshed daily; the sweep leaves it alone.</summary>
    [Fact]
    public void Sweep_LeavesTheSnapshotAlone()
    {
        using var factory = new BffFactory();
        factory.CreateClient();
        Age(factory.SnapshotPath, PastTheLimit);

        factory.Sweep();

        Assert.True(File.Exists(factory.SnapshotPath));
    }

    /// <summary>A store nothing has landed in yet is nothing to sweep, not something to fail on.</summary>
    [Fact]
    public void Sweep_WithNothingStoredYet_DoesNothing()
    {
        using var factory = new BffFactory();
        factory.CreateClient();

        factory.Sweep();

        Assert.False(Directory.Exists(factory.LogoDirectory));
        Assert.False(Directory.Exists(factory.PosterDirectory));
    }
}
