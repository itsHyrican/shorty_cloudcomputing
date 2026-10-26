using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Shorty.Controllers;
using Shorty.Entities;
using Shorty.Models;
using Shorty.Services;

namespace Shorty.Tests.Controllers;

public class ShortUrlControllerTests
{
    private readonly Mock<IShortUrlService> _serviceMock = new();
    private readonly ShortUrlController _controller;

    public ShortUrlControllerTests()
    {
        _controller = new ShortUrlController(_serviceMock.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
        };
    }

    [Fact]
    public async Task Create_WithValidRequest_ReturnsCreatedWithLocationAndBody()
    {
        var entity = new ShortUrl
        {
            Code = "abc123",
            OriginalUrl = "https://example.com",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(1)
        };
        _serviceMock
            .Setup(service => service.CreateAsync("https://example.com", 3600))
            .ReturnsAsync(entity);

        var result = await _controller.Create(new CreateShortUrlRequest("https://example.com", 3600));

        var created = Assert.IsType<CreatedResult>(result);
        Assert.Equal("/abc123", created.Location);

        var body = Assert.IsType<ShortUrlResponse>(created.Value);
        Assert.Equal("abc123", body.Code);
        Assert.Equal("/abc123", body.ShortUrl);
        Assert.Equal("https://example.com", body.OriginalUrl);
        Assert.Equal(entity.CreatedAt, body.CreatedAt);
        Assert.Equal(entity.ExpiresAt, body.ExpiresAt);

        _serviceMock.Verify(service => service.CreateAsync("https://example.com", 3600), Times.Once);
    }

    [Fact]
    public async Task Create_WithoutTtl_ForwardsNullTtlToService()
    {
        var entity = new ShortUrl
        {
            Code = "abc123",
            OriginalUrl = "https://example.com",
            CreatedAt = DateTime.UtcNow
        };
        _serviceMock
            .Setup(service => service.CreateAsync("https://example.com", null))
            .ReturnsAsync(entity);

        var result = await _controller.Create(new CreateShortUrlRequest("https://example.com", null));

        Assert.IsType<CreatedResult>(result);
        _serviceMock.Verify(service => service.CreateAsync("https://example.com", null), Times.Once);
    }

    [Fact]
    public async Task Create_WithNullRequest_ReturnsBadRequest()
    {
        var result = await _controller.Create(null!);

        Assert.IsType<BadRequestObjectResult>(result);
        _serviceMock.Verify(service => service.CreateAsync(It.IsAny<string>(), It.IsAny<int?>()), Times.Never);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Create_WithBlankUrl_ReturnsBadRequest(string url)
    {
        var result = await _controller.Create(new CreateShortUrlRequest(url, null));

        Assert.IsType<BadRequestObjectResult>(result);
        _serviceMock.Verify(service => service.CreateAsync(It.IsAny<string>(), It.IsAny<int?>()), Times.Never);
    }

    [Fact]
    public async Task Create_WhenServiceRejectsInput_ReturnsBadRequestWithErrorMessage()
    {
        _serviceMock
            .Setup(service => service.CreateAsync("not a url", null))
            .ThrowsAsync(new InvalidOperationException("\"not a url\" is not a valid absolute http(s) URL."));

        var result = await _controller.Create(new CreateShortUrlRequest("not a url", null));

        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        var errorProperty = badRequest.Value!.GetType().GetProperty("error")!;
        Assert.Contains("is not a valid absolute http(s) URL", (string)errorProperty.GetValue(badRequest.Value)!);
    }
}
