using Shorty.Entities;

namespace Shorty.Services;

public interface IShortUrlService
{
    /// <summary>
    /// Creates a new short URL for the given original URL.
    /// </summary>
    /// <param name="url">The original URL to shorten.</param>
    /// <param name="ttlSeconds">
    /// Optional lifetime in seconds. Falls back to the configured default TTL and is capped
    /// by the configured maximum TTL.
    /// </param>
    /// <exception cref="InvalidOperationException">
    /// Thrown when <paramref name="url"/> is not a valid absolute http(s) URL or the requested
    /// TTL is invalid.
    /// </exception>
    Task<ShortUrl> CreateAsync(string url, int? ttlSeconds = null);

    /// <summary>
    /// Looks up a short URL by its code (case-insensitive). Returns <c>null</c> when the code is unknown.
    /// Note: the returned entity may already be expired – callers decide how to handle that.
    /// </summary>
    Task<ShortUrl?> FindByCodeAsync(string code);
}
