namespace Shorty.Models;

/// <summary>
/// Response returned after a short URL has been created.
/// </summary>
public record ShortUrlResponse(string Code, string ShortUrl, string OriginalUrl, DateTime CreatedAt, DateTime? ExpiresAt);
