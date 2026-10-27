using Testcontainers.PostgreSql;

namespace Shorty.IntegrationTests;

/// <summary>
/// Boots a real PostgreSQL container (Testcontainers) and the full Shorty API
/// (in-process via WebApplicationFactory) once for the whole test class. All
/// integration tests run sequentially against one migrated database.
/// </summary>
public sealed class ShortyApiFixture : IAsyncLifetime
{
    private PostgreSqlContainer? _postgres;
    private ShortyApiFactory? _factory;

    public ShortyApiFactory Factory =>
        _factory ?? throw new InvalidOperationException("Fixture has not been initialized yet.");

    public async Task InitializeAsync()
    {
        _postgres = new PostgreSqlBuilder()
            .WithImage("postgres:16-alpine")
            .WithDatabase("shorty")
            .WithUsername("shorty")
            .WithPassword("shorty")
            .Build();

        await _postgres.StartAsync();
        _factory = new ShortyApiFactory(_postgres.GetConnectionString());
    }

    public async Task DisposeAsync()
    {
        if (_factory is not null)
        {
            await _factory.DisposeAsync();
            _factory = null;
        }

        if (_postgres is not null)
        {
            await _postgres.DisposeAsync();
            _postgres = null;
        }
    }
}
