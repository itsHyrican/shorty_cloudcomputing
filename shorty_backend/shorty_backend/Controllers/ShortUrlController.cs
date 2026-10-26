using Microsoft.AspNetCore.Mvc;
using Shorty.Entities;
using Shorty.Models;
using Shorty.Services;

namespace Shorty.Controllers;

[ApiController]
[Route("api/shorturls")]
public class ShortUrlController : ControllerBase
{
    private readonly IShortUrlService _shortUrlService;

    public ShortUrlController(IShortUrlService shortUrlService)
    {
        _shortUrlService = shortUrlService;
    }

    /// <summary>
    /// Creates a short URL for the given original URL. An optional <c>ttlSeconds</c> value
    /// overrides the configured default TTL (capped by the configured maximum).
    /// </summary>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] CreateShortUrlRequest request)
    {
        if (request is null || string.IsNullOrWhiteSpace(request.Url))
        {
            return BadRequest(new { error = "Property 'Url' is required." });
        }

        try
        {
            var shortUrl = await _shortUrlService.CreateAsync(request.Url, request.TtlSeconds);

            return Created($"/{shortUrl.Code}", ToResponse(shortUrl));
        }
        catch (InvalidOperationException exception)
        {
            return BadRequest(new { error = exception.Message });
        }
    }

    private static ShortUrlResponse ToResponse(ShortUrl shortUrl) =>
        new(shortUrl.Code, $"/{shortUrl.Code}", shortUrl.OriginalUrl, shortUrl.CreatedAt, shortUrl.ExpiresAt);
}
