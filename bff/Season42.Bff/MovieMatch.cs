namespace Season42.Bff;

/// <summary>
/// A movie TMDB matched a search on: its id and its title, and nothing else. This is the whole
/// of what a search answers with — an overview and a poster belong to the details of one match,
/// which is a separate ask.
/// </summary>
/// <remarks>
/// The id is TMDB's, and it is what the app asks the next question with. It is never stored:
/// the Library holds what the user copied, not a link back to someone else's record.
/// </remarks>
/// <remarks>
/// A movie is titled where a series is named, and each is spelled the way TMDB spells it, so
/// that nothing between here and TMDB has to remember a renaming of its own.
/// </remarks>
public sealed record MovieMatch(int Id, string Title);
