using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using Shorty.Configuration;
using Shorty.Data;
using Shorty.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();

// Allow the Angular frontend (different origin/port during development)
// to call the API from the browser.
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Shorty API",
        Version = "v1",
        Description = "Create short URLs with an optional TTL and resolve them."
    });

    // Surface the XML doc comments from the source code in the Swagger UI.
    options.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, "shorty_backend.xml"));
});

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("Connection string 'DefaultConnection' is not configured.");

builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(connectionString));

builder.Services.Configure<ShortUrlOptions>(builder.Configuration.GetSection("ShortUrlOptions"));
builder.Services.AddScoped<IShortUrlService, ShortUrlService>();
builder.Services.AddHostedService<ExpiredShortUrlCleanupService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
// Served in every environment, including the containerized Production setup.
app.UseSwagger();
app.UseSwaggerUI();
app.UseCors();

// Apply pending EF Core migrations. Retries briefly so the app can come up
// while the database container is still starting.
for (var attempt = 1; ; attempt++)
{
    try
    {
        using var scope = app.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await dbContext.Database.MigrateAsync();
        break;
    }
    catch (Exception exception) when (attempt < 15)
    {
        Console.WriteLine($"[startup] Database not reachable yet (attempt {attempt}/15): {exception.Message}");
        await Task.Delay(TimeSpan.FromSeconds(2));
    }
}

app.MapControllers();

app.Run();

// Marker class so WebApplicationFactory<Program> in the integration tests can
// discover the application entry point from another assembly.
public partial class Program
{
}
