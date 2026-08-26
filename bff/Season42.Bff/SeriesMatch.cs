namespace Season42.Bff;

/// <summary>
/// A series TMDB matched a search on: its id and its name, and nothing else. This is the whole
/// of what a search answers with — an overview, a poster and the season list belong to the
/// details of one match, which is a separate ask.
/// </summary>
/// <remarks>
/// The id is TMDB's, and it is what the app asks the next question with. It is never stored:
/// the Library holds what the user copied, not a link back to someone else's record.
/// </remarks>
public sealed record SeriesMatch(int Id, string Name);
