namespace Shorty.Configuration;

/// <summary>
/// Lifetime settings for short URLs. Bound from the "ShortUrlOptions" configuration section.
/// </summary>
public class ShortUrlOptions
{
    /// <summary>
    /// Default lifetime of a new link in hours. Values &lt;= 0 create permanent links.
    /// </summary>
    public double DefaultTtlHours { get; set; } = 24;

    /// <summary>
    /// Upper bound for per-request TTLs, in hours.
    /// </summary>
    public double MaxTtlHours { get; set; } = 720;

    /// <summary>
    /// How often (in minutes) expired links are purged from the database.
    /// </summary>
    public int CleanupIntervalMinutes { get; set; } = 15;
}
