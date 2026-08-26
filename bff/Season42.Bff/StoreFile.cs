namespace Season42.Bff;

/// <summary>
/// Writing one fetched file into a store, whole or not at all. The two stores that fill
/// themselves from TMDB — <see cref="LogoStore"/> keyed on the path TMDB published,
/// <see cref="PosterStore"/> keyed on the series id — differ in what they decide to write and
/// what they call it (ADR-0012), and not at all in how the bytes land.
/// </summary>
internal static class StoreFile
{
    // A file being written is not a file that can be served, so it is written under another name
    // and moved into place — a reader either sees no file or sees a whole one.
    private const string PartialSuffix = ".partial";

    /// <summary>
    /// Puts <paramref name="bytes"/> at <paramref name="path"/>, creating the store directory if
    /// this is the first thing to land in it. A store that cannot be written is logged and
    /// nothing more: whoever asked already has the bytes, and all that is lost is the saving on
    /// the next ask.
    /// </summary>
    public static async Task WriteAsync(
        string path, byte[] bytes, ILogger log, CancellationToken cancellationToken)
    {
        var partial = path + PartialSuffix;
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            await File.WriteAllBytesAsync(partial, bytes, cancellationToken);
            File.Move(partial, path, overwrite: true);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            log.LogWarning(exception, "Could not write {Path} into the store.", path);
        }
    }
}
