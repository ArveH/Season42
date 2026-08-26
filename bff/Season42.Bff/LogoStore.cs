using System.Collections.Concurrent;
using Microsoft.Extensions.Options;

namespace Season42.Bff;

/// <summary>
/// The logo bytes on disk, filling itself from TMDB as logos are asked for. Nothing here expires
/// and nothing needs invalidating: a logo that has been published does not change under its own
/// path, so each one costs at most one fetch for the life of the store (ADR-0007).
/// </summary>
public sealed class LogoStore
{
    /// <summary>The logo bytes sit beside the snapshot, not among it.</summary>
    public const string DirectoryName = "logos";

    // A file being written is not a file that can be served, so it is written under another name
    // and moved into place — a reader either sees no logo or sees a whole one.
    private const string PartialSuffix = ".partial";

    private readonly string _directory;
    private readonly IServiceProvider _services;
    private readonly ILogger<LogoStore> _log;

    // One gate per logo, so that two requests for the same missing logo cost one fetch rather than
    // two. Gates are kept rather than reclaimed: there are only ever as many as the snapshot names.
    private readonly ConcurrentDictionary<string, SemaphoreSlim> _fetching = new(StringComparer.Ordinal);

    public LogoStore(
        IOptions<TmdbOptions> options,
        IHostEnvironment environment,
        IServiceProvider services,
        ILogger<LogoStore> log)
    {
        _services = services;
        _log = log;
        _directory = Path.Combine(options.Value.StoreRootFrom(environment), DirectoryName);
    }

    /// <summary>
    /// The bytes of one logo, from the store if it is there and from TMDB if it is not.
    /// <paramref name="file"/> must already have been found in the current snapshot: this method
    /// puts it straight onto the filesystem and does no checking of its own.
    /// </summary>
    /// <exception cref="HttpRequestException">TMDB could not serve the logo.</exception>
    public async Task<byte[]> ReadOrFetchAsync(string file, CancellationToken cancellationToken)
    {
        var path = Path.Combine(_directory, file);
        if (File.Exists(path)) return await File.ReadAllBytesAsync(path, cancellationToken);

        var gate = _fetching.GetOrAdd(file, _ => new SemaphoreSlim(1, 1));
        await gate.WaitAsync(cancellationToken);
        try
        {
            // Whoever held the gate may have been fetching this very logo.
            if (File.Exists(path)) return await File.ReadAllBytesAsync(path, cancellationToken);

            // Resolved per fetch rather than held: TmdbLogoImages is a typed HttpClient, and a
            // singleton holding one would pin a single handler for the life of the server.
            using var scope = _services.CreateScope();
            var tmdb = scope.ServiceProvider.GetRequiredService<TmdbLogoImages>();

            var bytes = await tmdb.FetchAsync(file, cancellationToken);
            await WriteAsync(path, bytes, cancellationToken);
            return bytes;
        }
        finally
        {
            gate.Release();
        }
    }

    /// <summary>What to serve the bytes as, read from the path TMDB published them under.</summary>
    public static string ContentTypeOf(string file) => Path.GetExtension(file).ToLowerInvariant() switch
    {
        ".jpg" or ".jpeg" => "image/jpeg",
        ".png" => "image/png",
        // The two TMDB publishes provider logos as. Anything else is still served, but as bytes
        // rather than as something a browser will try to interpret — an SVG served from this
        // server's own origin would be a script this server had published.
        _ => "application/octet-stream",
    };

    private async Task WriteAsync(string path, byte[] bytes, CancellationToken cancellationToken)
    {
        var partial = path + PartialSuffix;
        try
        {
            Directory.CreateDirectory(_directory);
            await File.WriteAllBytesAsync(partial, bytes, cancellationToken);
            File.Move(partial, path, overwrite: true);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // The caller already has the bytes; all that is lost is the saving on the next ask.
            _log.LogWarning(exception, "Could not write the logo {Path} into the store.", path);
        }
    }
}
