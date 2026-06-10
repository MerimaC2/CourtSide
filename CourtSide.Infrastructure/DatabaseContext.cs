using System.Linq.Expressions;
using CourtSide.Core.Entities;
using CourtSide.Core.Entities.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Infrastructure;

public class DatabaseContext : IdentityDbContext<ApplicationUser, ApplicationRole, int>
{
    public DatabaseContext(DbContextOptions<DatabaseContext> options) : base(options) { }

    public DbSet<Country> Countries => Set<Country>();
    public DbSet<City> Cities => Set<City>();
    public DbSet<Sport> Sports => Set<Sport>();
    public DbSet<SportCenter> SportCenters => Set<SportCenter>();
    public DbSet<Court> Courts => Set<Court>();
    public DbSet<CourtImage> CourtImages => Set<CourtImage>();
    public DbSet<CourtWorkingHours> CourtWorkingHours => Set<CourtWorkingHours>();
    public DbSet<CourtAvailabilityBlock> CourtAvailabilityBlocks => Set<CourtAvailabilityBlock>();
    public DbSet<Reservation> Reservations => Set<Reservation>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<CourtReview> CourtReviews => Set<CourtReview>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<News> News => Set<News>();
    public DbSet<CourtViewLog> CourtViewLogs => Set<CourtViewLog>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // ----- Reservation has three FKs to ApplicationUser: disambiguate them explicitly. -----
        builder.Entity<Reservation>()
            .HasOne(r => r.Client).WithMany(u => u.Reservations)
            .HasForeignKey(r => r.ClientId).OnDelete(DeleteBehavior.Restrict);
        builder.Entity<Reservation>()
            .HasOne(r => r.ConfirmedBy).WithMany()
            .HasForeignKey(r => r.ConfirmedById).OnDelete(DeleteBehavior.Restrict);
        builder.Entity<Reservation>()
            .HasOne(r => r.CancelledBy).WithMany()
            .HasForeignKey(r => r.CancelledById).OnDelete(DeleteBehavior.Restrict);

        // ----- Default every FK to Restrict to avoid SQL Server multiple-cascade-path errors. -----
        foreach (var fk in builder.Model.GetEntityTypes().SelectMany(e => e.GetForeignKeys()))
        {
            fk.DeleteBehavior = DeleteBehavior.Restrict;
        }

        // ----- Opt specific child relationships back into cascade delete (owned-style children). -----
        builder.Entity<CourtImage>()
            .HasOne(x => x.Court).WithMany(c => c.Images)
            .HasForeignKey(x => x.CourtId).OnDelete(DeleteBehavior.Cascade);

        builder.Entity<CourtWorkingHours>()
            .HasOne(x => x.Court).WithMany(c => c.WorkingHours)
            .HasForeignKey(x => x.CourtId).OnDelete(DeleteBehavior.Cascade);

        builder.Entity<Payment>()
            .HasOne(x => x.Reservation).WithOne(r => r.Payment)
            .HasForeignKey<Payment>(x => x.ReservationId).OnDelete(DeleteBehavior.Cascade);

        // ----- Unique constraints. -----
        builder.Entity<Reservation>().HasIndex(x => x.ReservationNumber).IsUnique();
        builder.Entity<Payment>().HasIndex(x => x.ReservationId).IsUnique();

        // ----- Helpful indexes for filtering. -----
        builder.Entity<Reservation>().HasIndex(x => new { x.CourtId, x.Date });
        builder.Entity<Reservation>().HasIndex(x => x.Status);
        builder.Entity<CourtViewLog>().HasIndex(x => new { x.UserId, x.CourtId });

        // ----- Global soft-delete query filter for every entity exposing an IsDeleted flag. -----
        foreach (var entityType in builder.Model.GetEntityTypes())
        {
            if (entityType.FindProperty("IsDeleted") is null) continue;

            var param = Expression.Parameter(entityType.ClrType, "e");
            var body = Expression.Equal(
                Expression.Property(param, "IsDeleted"),
                Expression.Constant(false));
            builder.Entity(entityType.ClrType).HasQueryFilter(Expression.Lambda(body, param));
        }
    }

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        // All money values use SQL decimal(18,2).
        configurationBuilder.Properties<decimal>().HavePrecision(18, 2);
    }
}
