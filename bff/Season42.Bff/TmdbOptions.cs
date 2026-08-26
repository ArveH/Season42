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

    /// <summary>A TMDB v4 Read Access Token. Empty is a startup failure, not a first-search failure.</summary>
    public string AccessToken { get; set; } = "";

    /// <summary>The country whose TV watch providers are fetched.</summary>
    public string WatchRegion { get; set; } = "NO";

    /// <summary>
    /// Where everything fetched from TMDB is kept — the snapshot, and the logo bytes once there are
    /// any. Relative paths are content-root relative. Nothing the user owns is in here: deleting it
    /// costs a fetch (ADR-0007).
    /// </summary>
    public string LogoStorePath { get; set; } = "store";
}
