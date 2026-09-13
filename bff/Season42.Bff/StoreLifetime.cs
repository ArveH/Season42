namespace Season42.Bff;

/// <summary>
/// How long anything fetched from TMDB may be kept, and what that means for a file already on
/// disk. Both stores that fill themselves from TMDB — <see cref="LogoStore"/> and
/// <see cref="PosterStore"/> — ask this rather than each deciding for itself, because the limit is
/// one rule from outside them both (ADR-0020).
/// </summary>
internal static class StoreLifetime
{
    /// <summary>
    /// The longest anything fetched from TMDB may be kept. TMDB's API Terms of Use, section 1.C,
    /// forbid caching "any information obtained through or from TMDB" for longer than six months;
    /// 180 days is inside the shortest six calendar months there are, so a stored file that has
    /// not aged past it has not aged past the clause either, whenever it was fetched.
    /// </summary>
    public static readonly TimeSpan Limit = TimeSpan.FromDays(180);

    /// <summary>
    /// The bytes at <paramref name="path"/>, or null where there are none to serve — no file, or
    /// one that has aged past <see cref="Limit"/>, which is deleted as it is found rather than
    /// left for the sweep. Whoever asked then pays for a fetch, which is all a lost image costs.
    /// </summary>
    public static async Task<byte[]?> ReadIfFreshAsync(
        string path, ILogger log, CancellationToken cancellationToken)
    {
        if (!File.Exists(path)) return null;

        if (HasAged(File.GetLastWriteTimeUtc(path)))
        {
            // Dropped whether or not the fetch about to be made succeeds. Serving it while TMDB
            // is unreachable would be keeping it past the limit for as long as the outage lasts,
            // which is not this server's to decide.
            Delete(path, log);
            return null;
        }

        try
        {
            return await File.ReadAllBytesAsync(path, cancellationToken);
        }
        catch (FileNotFoundException)
        {
            // A sweep got between the check and the read. There is no file, which is an answer
            // this method already has a way of giving.
            return null;
        }
    }

    /// <summary>
    /// Deletes everything under <paramref name="directory"/> that has aged past
    /// <see cref="Limit"/>, and answers how many went. A directory nothing has landed in yet is
    /// nothing to sweep rather than something to fail on.
    /// </summary>
    public static int EvictAgedUnder(string directory, ILogger log)
    {
        if (!Directory.Exists(directory)) return 0;

        var evicted = 0;
        // Recursive, because a poster is kept under the kind of thing it is a poster of and so
        // sits a folder below the store's own (ADR-0012).
        foreach (var path in Directory.EnumerateFiles(directory, "*", SearchOption.AllDirectories))
        {
            try
            {
                if (!HasAged(File.GetLastWriteTimeUtc(path))) continue;
            }
            catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
            {
                // Something moved under the sweep, which is a request being served. It will be
                // swept the next time round if it is still there to sweep.
                continue;
            }

            if (Delete(path, log)) evicted++;
        }

        return evicted;
    }

    /// <summary>When a file was fetched is when it was written, which is all this store records.</summary>
    private static bool HasAged(DateTime writtenUtc) => DateTime.UtcNow - writtenUtc > Limit;

    /// <summary>
    /// Removes one file. A file that cannot be removed is logged and nothing more: what is lost
    /// is an eviction, and the read path refuses to serve it regardless of what the disk allows.
    /// </summary>
    private static bool Delete(string path, ILogger log)
    {
        try
        {
            File.Delete(path);
            return true;
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            log.LogWarning(exception, "Could not evict {Path} from the store.", path);
            return false;
        }
    }
}
