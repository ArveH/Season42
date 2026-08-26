namespace Season42.Bff;

/// <summary>
/// A service TMDB knows of: a name, a logo and where TMDB would place it in a list. This is all
/// of TMDB's answer that survives the fetch — the per-country priority map and the provider id
/// are dropped on the way in (ADR-0007).
/// </summary>
public sealed record WatchProvider(string Name, string LogoPath, int DisplayPriority);
