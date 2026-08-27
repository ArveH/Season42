namespace Season42.Bff;

/// <summary>
/// Everything the app shows about one movie it opened: what it is called, what it is called
/// where it was made, what it is about, and whether there is a poster to ask for. This is the
/// whole of it — the runtime, the budget and the release date TMDB also knows are not here,
/// because nothing on the detail screen shows them.
/// </summary>
/// <remarks>
/// There are no seasons, which is the whole of what separates this from a
/// <see cref="SeriesDetails"/>: a movie is one thing to watch, so nothing here is flattened and
/// nothing about it is invented.
/// </remarks>
/// <remarks>
/// TMDB's poster path is not among them. Whether there is a poster is a yes or a no, and the
/// poster itself is asked for by the id the app already has: a path the app could send is a path
/// this server would have to defend against, and there is none (ADR-0012). The yes or no is here
/// so the app can draw its placeholder without firing an ask it expects to be refused.
/// </remarks>
/// <remarks>
/// The id it was asked for is not answered back. The app already has it, from the
/// <see cref="MovieMatch"/> it opened, and it is never stored on either side: the Library holds
/// what the user copied, not a link back to someone else's record (ADR-0002).
/// </remarks>
public sealed record MovieDetails(
    string Title,
    string OriginalTitle,
    string Overview,
    bool HasPoster);
