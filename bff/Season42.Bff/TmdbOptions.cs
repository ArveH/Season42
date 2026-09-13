namespace Season42.Bff;

/// <summary>
/// Everything the BFF needs to talk to TMDB and to keep what it gets back. The token is the
/// reason this server exists: it is read here and never leaves the machine.
/// </summary>
public sealed class TmdbOptions
{
    public const string SectionName = "Tmdb";

    /// <summary>The configuration key the token is read from, named in the startup failure.</summary>
    public const string AccessTokenKey = $"{SectionName}:{nameof(AccessToken)}";

    /// <summary>The file the last good snapshot is written to, inside <see cref="LogoStorePath"/>.</summary>
    public const string SnapshotFileName = "watch-providers.json";

    /// <summary>A TMDB API Read Access Token. Empty is a startup failure, not a first-search failure.</summary>
    public string AccessToken { get; set; } = "";

    /// <summary>The country whose TV watch providers are fetched.</summary>
    public string WatchRegion { get; set; } = "NO";

    /// <summary>
    /// Where everything fetched from TMDB is kept — the snapshot, and the logo bytes once there are
    /// any. Relative paths are content-root relative. Nothing the user owns is in here: deleting it
    /// costs a fetch (ADR-0007).
    /// </summary>
    public string LogoStorePath { get; set; } = "store";

    /// <summary>
    /// Where the store actually sits, once a relative <see cref="LogoStorePath"/> has been read
    /// against the content root. Both stores rooted here ask this rather than resolving it again.
    /// </summary>
    public string StoreRootFrom(IHostEnvironment environment) =>
        Path.GetFullPath(LogoStorePath, environment.ContentRootPath);

    /// <summary>
    /// The longest a fetched image may be kept whatever <see cref="ImageLifetimeDays"/> says.
    /// TMDB's API Terms of Use, section 1.C, forbid caching "any information obtained through or
    /// from TMDB" for longer than six months, and the shortest six calendar months there are come
    /// to 181 days. An image nobody asks for again is only reached by the daily sweep, so what has
    /// to fit inside those 181 days is this ceiling plus a sweep's worth of lag — not the ceiling
    /// alone. 170 leaves that margin several times over, and nothing configured can raise it
    /// (ADR-0020).
    /// </summary>
    public const double MaxImageLifetimeDays = 170;

    /// <summary>
    /// How long a fetched logo or poster is kept before it is dropped and fetched again, in days.
    /// A day by default: what a store buys is the fetches it saves, and on a server with few
    /// enough users that the same image is rarely asked for twice in a week, a longer one buys
    /// little and keeps someone else's pictures around for no reason. Raise it as traffic makes
    /// the saving real; anything above <see cref="MaxImageLifetimeDays"/> is clamped to it, and
    /// zero or less keeps nothing at all.
    /// </summary>
    public double ImageLifetimeDays { get; set; } = 1;

    /// <summary>
    /// How long an image is actually kept: what was configured, or the clause's ceiling where
    /// that is higher. Both stores and the sweep ask this rather than reading the setting.
    /// </summary>
    public TimeSpan ImageLifetime =>
        TimeSpan.FromDays(Math.Clamp(ImageLifetimeDays, 0, MaxImageLifetimeDays));
}
