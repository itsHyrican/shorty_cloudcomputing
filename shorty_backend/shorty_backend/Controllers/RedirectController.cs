using Microsoft.AspNetCore.Mvc;
using Shorty.Services;

namespace Shorty.Controllers;

/// <summary>
/// Resolves short codes to their original URLs. Any single-segment path that does not match
/// a more specific route (e.g. /health) is treated as a short code.
/// </summary>
[ApiController]
[Route("{code}")]
public class RedirectController : ControllerBase
{
    private readonly IShortUrlService _shortUrlService;

    public RedirectController(IShortUrlService shortUrlService)
    {
        _shortUrlService = shortUrlService;
    }

    /// <summary>
    /// Redirects (302) to the original URL stored for the given code.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status302Found)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status410Gone)]
    public async Task<IActionResult> Resolve(string code)
    {
        var shortUrl = await _shortUrlService.FindByCodeAsync(code);

        if (shortUrl is null)
        {
            return NotFound(new { error = $"Unknown short code '{code}'." });
        }

        if (shortUrl.ExpiresAt is not null && shortUrl.ExpiresAt <= DateTime.UtcNow)
        {
            return StatusCode(StatusCodes.Status410Gone, new { error = $"Short code '{code}' has expired." });
        }

        return Redirect(shortUrl.OriginalUrl);
    }
}
