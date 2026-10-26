using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Shorty.Configuration;
using Shorty.Data;

namespace Shorty.Services;

/// <summary>
/// Periodically removes expired short URLs so the table does not grow unbounded.
/// </summary>
public class ExpiredShortUrlCleanupService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IOptions<ShortUrlOptions> _options;
    private readonly ILogger<ExpiredShortUrlCleanupService> _logger;

    public ExpiredShortUrlCleanupService(
        IServiceScopeFactory scopeFactory,
        IOptions<ShortUrlOptions> options,
        ILogger<ExpiredShortUrlCleanupService> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var interval = TimeSpan.FromMinutes(Math.Max(1, _options.Value.CleanupIntervalMinutes));

            try
            {
                await Task.Delay(interval, stoppingToken);
                await CleanupAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                // A failed cleanup run must not take down the whole host – retry on the next tick.
                _logger.LogError(exception, "Failed to delete expired short URLs.");
            }
        }
    }

    /// <summary>
    /// Removes all expired short URLs from the database.
    /// </summary>
    public async Task CleanupAsync(CancellationToken cancellationToken = default)
    {
        // AppDbContext is scoped, so each run needs its own scope.
        using var scope = _scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var expired = await dbContext.ShortUrls
            .Where(shortUrl => shortUrl.ExpiresAt != null && shortUrl.ExpiresAt <= DateTime.UtcNow)
            .ToListAsync(cancellationToken);

        if (expired.Count == 0)
        {
            return;
        }

        dbContext.ShortUrls.RemoveRange(expired);
        await dbContext.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Deleted {Count} expired short URL(s).", expired.Count);
    }
}
