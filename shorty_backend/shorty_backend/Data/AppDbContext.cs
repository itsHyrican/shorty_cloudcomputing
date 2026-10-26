using Microsoft.EntityFrameworkCore;
using Shorty.Entities;

namespace Shorty.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    public DbSet<ShortUrl> ShortUrls => Set<ShortUrl>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ShortUrl>(entity =>
        {
            entity.ToTable("ShortUrls");
            entity.HasKey(e => e.Code);
            entity.Property(e => e.Code).HasMaxLength(16).IsRequired();
            entity.Property(e => e.OriginalUrl).HasMaxLength(2048).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
        });
    }
}
