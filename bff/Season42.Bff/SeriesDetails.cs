namespace Season42.Bff;

/// <summary>
/// Everything the app shows about one series it opened: what it is called, what it is called
/// where it was made, what it is about, and what seasons it has. This is the whole of it — the
/// poster, the networks, the ratings and the air dates TMDB also knows are not here, because
/// nothing on the detail screen shows them.
/// </summary>
/// <remarks>
/// The id it was asked for is not answered back. The app already has it, from the
/// <see cref="SeriesMatch"/> it opened, and it is never stored on either side: the Library holds
/// what the user copied, not a link back to someone else's record (ADR-0002).
/// </remarks>
public sealed record SeriesDetails(
    string Name,
    string OriginalName,
    string Overview,
    IReadOnlyList<SeriesSeason> Seasons);

/// <summary>
/// One season of a series, as its number and how many episodes it has.
/// </summary>
/// <remarks>
/// Season 0 is TMDB's specials, and it comes through with the rest. Whether a Tracked Series
/// wants them is the app's product decision; this side translates TMDB's shape and makes none.
/// </remarks>
public sealed record SeriesSeason(int SeasonNumber, int EpisodeCount);
