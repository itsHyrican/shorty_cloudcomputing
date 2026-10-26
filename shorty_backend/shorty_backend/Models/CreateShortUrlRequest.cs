namespace Shorty.Models;

/// <summary>
/// Request payload for creating a short URL.
/// </summary>
/// <param name="Url">The original URL to shorten.</param>
/// <param name="TtlSeconds">
/// Optional lifetime in seconds. Falls back to the configured default TTL and is capped
/// by the configured maximum TTL.
/// </param>
public record CreateShortUrlRequest(string Url, int? TtlSeconds);
