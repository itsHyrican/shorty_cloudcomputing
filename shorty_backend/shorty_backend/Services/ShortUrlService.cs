using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Shorty.Configuration;
using Shorty.Data;
using Shorty.Entities;

namespace Shorty.Services;

/// <summary>
/// Persistence-backed implementation of <see cref="IShortUrlService"/> using EF Core and PostgreSQL.
/// </summary>
public class ShortUrlService : IShortUrlService
{
    private const int CodeLength = 6;
    private const int MaxGenerationAttempts = 10;

    // Base62 alphabet: URL-safe characters, ~56 billion possible 6-char codes.
    private static readonly char[] Alphabet =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".ToCharArray();

    private readonly AppDbContext _dbContext;
    private readonly IOptions<ShortUrlOptions> _options;

    public ShortUrlService(AppDbContext dbContext, IOptions<ShortUrlOptions> options)
    {
        _dbContext = dbContext;
        _options = options;
    }

    public async Task<ShortUrl> CreateAsync(string url, int? ttlSeconds = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(url);

        var normalizedUrl = url.Trim();

        if (!Uri.TryCreate(normalizedUrl, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            throw new InvalidOperationException($"\"{url}\" is not a valid absolute http(s) URL.");
        }

        var ttl = ResolveTtl(ttlSeconds);

        for (var attempt = 0; attempt < MaxGenerationAttempts; attempt++)
        {
            var candidate = new ShortUrl
            {
                Code = GenerateCode(),
                OriginalUrl = normalizedUrl,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = ttl.HasValue ? DateTime.UtcNow + ttl.Value : null
            };

            _dbContext.ShortUrls.Add(candidate);

            try
            {
                await _dbContext.SaveChangesAsync();
                return candidate;
            }
            catch (DbUpdateException)
            {
                // A concurrent request claimed the same code (unique index violation) – detach and retry.
                _dbContext.Entry(candidate).State = EntityState.Detached;
            }
        }

        throw new InvalidOperationException("Could not generate a unique short code. Please try again.");
    }

    public async Task<ShortUrl?> FindByCodeAsync(string code)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(code);

        // Case-insensitive lookup so codes like "Abc123" and "abc123" resolve identically.
        // ToLower() is translated to SQL lower() by EF Core / Npgsql.
        return await _dbContext.ShortUrls
            .AsNoTracking()
            .FirstOrDefaultAsync(shortUrl => shortUrl.Code.ToLower() == code.ToLowerInvariant());
    }

    /// <summary>
    /// Resolves the effective TTL: the client-provided value (validated against the configured
    /// maximum) or the configured default. Returns <c>null</c> for permanent links.
    /// </summary>
    private TimeSpan? ResolveTtl(int? requestedTtlSeconds)
    {
        var options = _options.Value;

        if (requestedTtlSeconds is null)
        {
            return options.DefaultTtlHours > 0 ? TimeSpan.FromHours(options.DefaultTtlHours) : null;
        }

        var ttlSeconds = requestedTtlSeconds.Value;

        if (ttlSeconds <= 0)
        {
            throw new InvalidOperationException("TtlSeconds must be greater than zero.");
        }

        var maxTtlSeconds = (long)(options.MaxTtlHours * 3600);
        if (ttlSeconds > maxTtlSeconds)
        {
            throw new InvalidOperationException(
                $"TtlSeconds exceeds the maximum allowed TTL of {maxTtlSeconds} seconds ({options.MaxTtlHours} h).");
        }

        return TimeSpan.FromSeconds(ttlSeconds);
    }

    private string GenerateCode()
    {
        Span<char> buffer = stackalloc char[CodeLength];

        for (var i = 0; i < CodeLength; i++)
        {
            buffer[i] = Alphabet[Random.Shared.Next(Alphabet.Length)];
        }

        return new string(buffer);
    }
}
