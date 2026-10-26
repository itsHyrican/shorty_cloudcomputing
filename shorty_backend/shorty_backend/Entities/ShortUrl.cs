namespace Shorty.Entities;

/// <summary>
/// Maps a unique short code to an original URL. Persisted via <c>AppDbContext</c>.
/// </summary>
public class ShortUrl
{
    public string Code { get; set; } = null!;

    public string OriginalUrl { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// Point in time at which the link expires. <c>null</c> means the link never expires.
    /// </summary>
    public DateTime? ExpiresAt { get; set; }
}
