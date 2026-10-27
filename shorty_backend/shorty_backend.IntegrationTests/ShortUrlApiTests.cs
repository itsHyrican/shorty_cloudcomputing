using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Shorty.Data;
using Shorty.Entities;

namespace Shorty.IntegrationTests;

/// <summary>
/// End-to-end tests for the Shorty API: the real HTTP pipeline (controllers,
/// services, EF Core) against a real PostgreSQL container.
/// </summary>
public sealed class ShortUrlApiTests(ShortyApiFixture fixture) : IClassFixture<ShortyApiFixture>
{
    // Auto-redirect following must be off: TestServer would otherwise intercept the
    // redirected request (e.g. to example.com) and feed it back into the app under test,
    // turning a correct 302 into a spurious 404.
    private readonly HttpClient _client = fixture.Factory.CreateClient(new WebApplicationFactoryClientOptions
    {
        AllowAutoRedirect = false,
    });

    [Fact]
    public async Task Health_Returns200()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Create_Returns201_WithCode_ShortUrl_AndOriginalUrl()
    {
        const string originalUrl = "https://example.com/some/long/path?query=value";

        var body = await CreateShortUrlAsync(originalUrl);

        var code = body.GetProperty("code").GetString();
        Assert.False(string.IsNullOrWhiteSpace(code));
        Assert.Equal($"/{code}", body.GetProperty("shortUrl").GetString());
        Assert.Equal(originalUrl, body.GetProperty("originalUrl").GetString());
        Assert.NotEqual(default, body.GetProperty("createdAt").GetDateTime());
    }

    [Fact]
    public async Task Create_WithoutTtl_AppliesConfiguredDefaultTtl()
    {
        var body = await CreateShortUrlAsync("https://example.com/default-ttl");

        var lifetime = body.GetProperty("expiresAt").GetDateTime() - body.GetProperty("createdAt").GetDateTime();

        // appsettings.json configures DefaultTtlHours = 24.
        var expected = TimeSpan.FromHours(24);
        Assert.InRange(lifetime, expected - TimeSpan.FromSeconds(2), expected + TimeSpan.FromSeconds(2));
    }

    [Fact]
    public async Task Create_WithTtlOverride_AppliesRequestedTtl()
    {
        var body = await CreateShortUrlAsync("https://example.com/custom-ttl", ttlSeconds: 900);

        var lifetime = body.GetProperty("expiresAt").GetDateTime() - body.GetProperty("createdAt").GetDateTime();

        var expected = TimeSpan.FromMinutes(15);
        Assert.InRange(lifetime, expected - TimeSpan.FromSeconds(2), expected + TimeSpan.FromSeconds(2));
    }

    [Theory]
    [InlineData("not a url")]
    [InlineData("ftp://example.com/file")]
    [InlineData("")]
    public async Task Create_WithInvalidUrl_Returns400(string url)
    {
        var response = await _client.PostAsJsonAsync("/api/shorturls", new { url });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Create_WithTtlAboveMaximum_Returns400()
    {
        // Configured maximum is 720 h = 2_592_000 s.
        var response = await _client.PostAsJsonAsync("/api/shorturls", new { url = "https://example.com/too-long", ttlSeconds = 2_592_001 });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Resolve_KnownCode_Returns302_PointingToOriginalUrl()
    {
        const string originalUrl = "https://example.com/redirect-target";
        var body = await CreateShortUrlAsync(originalUrl);
        var code = body.GetProperty("code").GetString()!;

        var response = await _client.GetAsync($"/{code}");

        Assert.Equal(HttpStatusCode.Found, response.StatusCode);
        Assert.Equal(originalUrl, response.Headers.Location?.ToString());
    }

    [Fact]
    public async Task Resolve_MatchesCodeCaseInsensitively()
    {
        var body = await CreateShortUrlAsync("https://example.com/case-insensitive");
        var code = body.GetProperty("code").GetString()!;

        var response = await _client.GetAsync($"/{code.ToUpperInvariant()}");

        Assert.Equal(HttpStatusCode.Found, response.StatusCode);
    }

    [Fact]
    public async Task Resolve_UnknownCode_Returns404()
    {
        var response = await _client.GetAsync("/definitely-not-a-code");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Resolve_ExpiredCode_Returns410()
    {
        // Insert an already-expired link directly into the database – no need to wait for the TTL to elapse.
        using var scope = fixture.Factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        dbContext.ShortUrls.Add(new ShortUrl
        {
            Code = "expired1",
            OriginalUrl = "https://example.com/gone",
            CreatedAt = DateTime.UtcNow.AddHours(-2),
            ExpiresAt = DateTime.UtcNow.AddHours(-1),
        });
        await dbContext.SaveChangesAsync();

        var response = await _client.GetAsync("/expired1");

        Assert.Equal(HttpStatusCode.Gone, response.StatusCode);
    }

    private async Task<JsonElement> CreateShortUrlAsync(string url, int? ttlSeconds = null)
    {
        var response = await _client.PostAsJsonAsync("/api/shorturls", new { url, ttlSeconds });
        Assert.True(
            response.IsSuccessStatusCode,
            $"Expected a successful creation but got {(int)response.StatusCode}: {await response.Content.ReadAsStringAsync()}");

        return (await response.Content.ReadFromJsonAsync<JsonElement>())!;
    }
}
