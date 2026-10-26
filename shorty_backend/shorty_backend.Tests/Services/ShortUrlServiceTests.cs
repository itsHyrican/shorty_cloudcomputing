using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Shorty.Configuration;
using Shorty.Data;
using Shorty.Entities;
using Shorty.Services;

namespace Shorty.Tests.Services;

public class ShortUrlServiceTests
{
    private const string ValidUrl = "https://example.com/very/long/path";

    private readonly AppDbContext _dbContext;
    private readonly ShortUrlService _service;

    public ShortUrlServiceTests()
    {
        // A unique in-memory database per test keeps the tests isolated from each other.
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        _dbContext = new AppDbContext(options);
        _service = new ShortUrlService(_dbContext, Options.Create(CreateDefaultOptions()));
    }

    private static ShortUrlOptions CreateDefaultOptions() => new()
    {
        DefaultTtlHours = 24,
        MaxTtlHours = 720,
        CleanupIntervalMinutes = 15
    };

    [Fact]
    public async Task CreateAsync_WithValidHttpUrl_PersistsEntityWithSixCharCode()
    {
        var created = await _service.CreateAsync(ValidUrl);

        Assert.Equal(6, created.Code.Length);
        Assert.Equal(ValidUrl, created.OriginalUrl);
        Assert.NotNull(await _dbContext.ShortUrls.FindAsync(created.Code));
    }

    [Fact]
    public async Task CreateAsync_TrimsSurroundingWhitespaceFromUrl()
    {
        var created = await _service.CreateAsync($"  {ValidUrl}  ");

        Assert.Equal(ValidUrl, created.OriginalUrl);
    }

    [Theory]
    [InlineData("not a url")]
    [InlineData("ftp://example.com/file.txt")]
    [InlineData("mailto:someone@example.com")]
    public async Task CreateAsync_WithNonHttpUrl_Throws(string url)
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.CreateAsync(url));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task CreateAsync_WithMissingUrl_Throws(string? url)
    {
        // ArgumentNullException (null) and ArgumentOutOfRangeException (whitespace) are both derived.
        await Assert.ThrowsAnyAsync<ArgumentException>(() => _service.CreateAsync(url!));
    }

    [Fact]
    public async Task CreateAsync_WithoutTtl_UsesConfiguredDefaultTtl()
    {
        var created = await _service.CreateAsync(ValidUrl);

        Assert.NotNull(created.ExpiresAt);
        var ttl = created.ExpiresAt!.Value - created.CreatedAt;
        // CreatedAt and ExpiresAt come from two UtcNow reads, so allow a small drift.
        Assert.InRange(ttl, TimeSpan.FromHours(24) - TimeSpan.FromSeconds(1), TimeSpan.FromHours(24) + TimeSpan.FromSeconds(1));
    }

    [Fact]
    public async Task CreateAsync_WithPermanentDefault_CreatesLinkWithoutExpiry()
    {
        var service = new ShortUrlService(_dbContext, Options.Create(new ShortUrlOptions { DefaultTtlHours = 0 }));

        var created = await service.CreateAsync(ValidUrl);

        Assert.Null(created.ExpiresAt);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-3600)]
    public async Task CreateAsync_WithNonPositiveTtl_Throws(int ttlSeconds)
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.CreateAsync(ValidUrl, ttlSeconds));
    }

    [Fact]
    public async Task CreateAsync_WithTtlAboveMaximum_Throws()
    {
        var maxSeconds = (int)(720 * 3600);

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.CreateAsync(ValidUrl, maxSeconds + 1));
    }

    [Fact]
    public async Task CreateAsync_WithTtlExactlyAtMaximum_Succeeds()
    {
        var maxSeconds = (int)(720 * 3600);

        var created = await _service.CreateAsync(ValidUrl, maxSeconds);

        var ttl = created.ExpiresAt!.Value - created.CreatedAt;
        Assert.InRange(ttl, TimeSpan.FromHours(720) - TimeSpan.FromSeconds(1), TimeSpan.FromHours(720) + TimeSpan.FromSeconds(1));
    }

    [Fact]
    public async Task FindByCode_FindsEntryCaseInsensitively()
    {
        _dbContext.ShortUrls.Add(new ShortUrl
        {
            Code = "AbC123",
            OriginalUrl = ValidUrl,
            CreatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var lowerCase = await _service.FindByCodeAsync("abc123");
        var upperCase = await _service.FindByCodeAsync("ABC123");

        Assert.Equal(ValidUrl, lowerCase!.OriginalUrl);
        Assert.Equal(ValidUrl, upperCase!.OriginalUrl);
    }

    [Fact]
    public async Task FindByCode_WithUnknownCode_ReturnsNull()
    {
        Assert.Null(await _service.FindByCodeAsync("doesnotexist"));
    }

    [Fact]
    public async Task FindByCode_WithExpiredEntry_StillReturnsEntry()
    {
        // Expiry handling belongs to the caller – the redirect controller decides about 410 Gone.
        _dbContext.ShortUrls.Add(new ShortUrl
        {
            Code = "expired1",
            OriginalUrl = ValidUrl,
            CreatedAt = DateTime.UtcNow.AddDays(-2),
            ExpiresAt = DateTime.UtcNow.AddDays(-1)
        });
        await _dbContext.SaveChangesAsync();

        var found = await _service.FindByCodeAsync("EXPIRED1");

        Assert.NotNull(found);
    }
}
