using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Moq;
using Shorty.Configuration;
using Shorty.Data;
using Shorty.Entities;
using Shorty.Services;

namespace Shorty.Tests.Services;

public class ExpiredShortUrlCleanupServiceTests
{
    private readonly AppDbContext _dbContext;
    private readonly ExpiredShortUrlCleanupService _service;

    public ExpiredShortUrlCleanupServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        _dbContext = new AppDbContext(options);
        _service = CreateService(_dbContext);
    }

    /// <summary>
    /// Wires the cleanup service against the given context: the scope factory is mocked so that
    /// <c>CleanupAsync</c> resolves the real (in-memory) context instead of opening a database connection.
    /// </summary>
    private static ExpiredShortUrlCleanupService CreateService(AppDbContext dbContext)
    {
        var provider = new Mock<IServiceProvider>();
        provider.Setup(p => p.GetService(typeof(AppDbContext))).Returns(dbContext);

        var scope = new Mock<IServiceScope>();
        scope.Setup(s => s.ServiceProvider).Returns(provider.Object);

        var scopeFactory = new Mock<IServiceScopeFactory>();
        scopeFactory.Setup(f => f.CreateScope()).Returns(scope.Object);

        return new ExpiredShortUrlCleanupService(
            scopeFactory.Object,
            Options.Create(new ShortUrlOptions()),
            NullLogger<ExpiredShortUrlCleanupService>.Instance);
    }

    [Fact]
    public async Task Cleanup_RemovesOnlyExpiredEntries()
    {
        var now = DateTime.UtcNow;
        _dbContext.ShortUrls.AddRange(
            new ShortUrl { Code = "expired", OriginalUrl = "https://example.com/a", CreatedAt = now.AddDays(-2), ExpiresAt = now.AddHours(-1) },
            new ShortUrl { Code = "active", OriginalUrl = "https://example.com/b", CreatedAt = now, ExpiresAt = now.AddHours(1) },
            new ShortUrl { Code = "permanent", OriginalUrl = "https://example.com/c", CreatedAt = now, ExpiresAt = null });
        await _dbContext.SaveChangesAsync();

        await _service.CleanupAsync();

        var remaining = await _dbContext.ShortUrls.Select(shortUrl => shortUrl.Code).ToListAsync();
        Assert.Equal(new[] { "active", "permanent" }, remaining.OrderBy(code => code));
    }

    [Fact]
    public async Task Cleanup_WithoutExpiredEntries_ChangesNothing()
    {
        var now = DateTime.UtcNow;
        _dbContext.ShortUrls.AddRange(
            new ShortUrl { Code = "active", OriginalUrl = "https://example.com/b", CreatedAt = now, ExpiresAt = now.AddHours(1) },
            new ShortUrl { Code = "permanent", OriginalUrl = "https://example.com/c", CreatedAt = now, ExpiresAt = null });
        await _dbContext.SaveChangesAsync();

        await _service.CleanupAsync();

        Assert.Equal(2, await _dbContext.ShortUrls.CountAsync());
    }
}
