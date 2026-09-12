namespace Season42.Bff;

/// <summary>How much of the server one caller may have (ADR-0017).</summary>
public sealed class RateLimitOptions
{
    public const string SectionName = "RateLimit";

    /// <summary>
    /// How many requests one caller may make within a window. The default is well above what the
    /// app does — a search, a details call and a poster is three — and well below what a script
    /// pointed at the TMDB token would want.
    /// </summary>
    public int PermitsPerWindow { get; set; } = 60;

    /// <summary>How long a window lasts, in seconds.</summary>
    public int WindowSeconds { get; set; } = 60;

    public TimeSpan Window => TimeSpan.FromSeconds(WindowSeconds);
}
