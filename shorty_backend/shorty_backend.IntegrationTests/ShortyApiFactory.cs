using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Shorty.IntegrationTests;

/// <summary>
/// Hosts the real Shorty API in-process and overrides the connection string so the
/// app talks to the test PostgreSQL container instead of a local database.
/// </summary>
public sealed class ShortyApiFactory : WebApplicationFactory<Program>
{
    private readonly string _connectionString;

    public ShortyApiFactory(string connectionString)
    {
        _connectionString = connectionString;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ConnectionStrings:DefaultConnection", _connectionString);
    }
}
