using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Shorty.Controllers;
using Shorty.Entities;
using Shorty.Services;

namespace Shorty.Tests.Controllers;

public class RedirectControllerTests
{
    private readonly Mock<IShortUrlService> _serviceMock = new();
    private readonly RedirectController _controller;

    public RedirectControllerTests()
    {
        _controller = new RedirectController(_serviceMock.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
        };
    }

    [Fact]
    public async Task Resolve_WithUnknownCode_ReturnsNotFound()
    {
        _serviceMock
            .Setup(service => service.FindByCodeAsync("missing"))
            .ReturnsAsync((ShortUrl?)null);

        var result = await _controller.Resolve("missing");

        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Resolve_WithActiveCode_RedirectsToOriginalUrl(bool permanent)
    {
        var now = DateTime.UtcNow;
        var entity = new ShortUrl
        {
            Code = "abc123",
            OriginalUrl = "https://example.com/target",
            CreatedAt = now,
            ExpiresAt = permanent ? null : now.AddHours(1)
        };
        _serviceMock
            .Setup(service => service.FindByCodeAsync("abc123"))
            .ReturnsAsync(entity);

        var result = await _controller.Resolve("abc123");

        var redirect = Assert.IsType<RedirectResult>(result);
        Assert.Equal("https://example.com/target", redirect.Url);
        Assert.False(redirect.Permanent);
    }

    [Fact]
    public async Task Resolve_WithExpiredCode_ReturnsGone()
    {
        var entity = new ShortUrl
        {
            Code = "oldcode",
            OriginalUrl = "https://example.com/gone",
            CreatedAt = DateTime.UtcNow.AddDays(-2),
            ExpiresAt = DateTime.UtcNow.AddHours(-1)
        };
        _serviceMock
            .Setup(service => service.FindByCodeAsync("oldcode"))
            .ReturnsAsync(entity);

        var result = await _controller.Resolve("oldcode");

        var gone = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status410Gone, gone.StatusCode);
    }
}
