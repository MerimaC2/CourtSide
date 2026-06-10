using CourtSide.Core.Entities;
using CourtSide.Core.Entities.Identity;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace CourtSide.Infrastructure.Seed;

/// <summary>Seeds roles, test users and reference/domain data (idempotent) at startup.</summary>
public static class DatabaseSeeder
{
    // 1x1 placeholder PNG — replaced with real court photos in a later phase.
    private static readonly byte[] PlaceholderImage =
        Convert.FromBase64String(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==");

    public static async Task SeedAsync(IServiceProvider services)
    {
        var db = services.GetRequiredService<DatabaseContext>();
        var userManager = services.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = services.GetRequiredService<RoleManager<ApplicationRole>>();

        await SeedRolesAsync(roleManager);
        await SeedUsersAsync(userManager);
        await SeedDomainAsync(db);
    }

    private static async Task SeedRolesAsync(RoleManager<ApplicationRole> roleManager)
    {
        foreach (var role in new[] { Roles.Admin, Roles.User })
        {
            if (!await roleManager.RoleExistsAsync(role))
                await roleManager.CreateAsync(new ApplicationRole { Name = role, Description = $"{role} role" });
        }
    }

    private static async Task SeedUsersAsync(UserManager<ApplicationUser> userManager)
    {
        await EnsureUserAsync(userManager, "admin", "admin@courtside.local", "Admin", "Korisnik", "test", Roles.Admin);
        await EnsureUserAsync(userManager, "desktop", "desktop@courtside.local", "Desktop", "Administrator", "test", Roles.Admin);
        await EnsureUserAsync(userManager, "mobile", "mobile@courtside.local", "Mobile", "Korisnik", "test", Roles.User);
    }

    private static async Task EnsureUserAsync(UserManager<ApplicationUser> userManager,
        string username, string email, string firstName, string lastName, string password, string role)
    {
        if (await userManager.FindByNameAsync(username) is not null) return;

        var user = new ApplicationUser
        {
            UserName = username,
            Email = email,
            EmailConfirmed = true,
            FirstName = firstName,
            LastName = lastName,
            CreatedAt = DateTime.UtcNow
        };

        var result = await userManager.CreateAsync(user, password);
        if (result.Succeeded)
            await userManager.AddToRoleAsync(user, role);
    }

    private static async Task SeedDomainAsync(DatabaseContext db)
    {
        if (await db.Sports.AnyAsync()) return;

        var now = DateTime.UtcNow;

        var bih = new Country { Name = "Bosna i Hercegovina", IsoCode = "BIH", CreatedAt = now };
        var mostar = new City { Name = "Mostar", PostalCode = "88000", Country = bih, CreatedAt = now };
        var sarajevo = new City { Name = "Sarajevo", PostalCode = "71000", Country = bih, CreatedAt = now };

        var futsal = new Sport { Name = "Futsal", Description = "Mali nogomet (5 na 5)", CreatedAt = now };
        var tenis = new Sport { Name = "Tenis", CreatedAt = now };
        var padel = new Sport { Name = "Padel", CreatedAt = now };
        var badminton = new Sport { Name = "Badminton", CreatedAt = now };

        var centerMo = new SportCenter
        {
            Name = "Sportski centar Mostar", Address = "Bulevar bb, Mostar",
            City = mostar, Latitude = 43.343, Longitude = 17.808, CreatedAt = now
        };
        var centerSa = new SportCenter
        {
            Name = "Padel Arena Sarajevo", Address = "Zmaja od Bosne 4, Sarajevo",
            City = sarajevo, Latitude = 43.856, Longitude = 18.413, CreatedAt = now
        };

        db.Courts.AddRange(
            CreateCourt("Futsal teren 1", futsal, centerMo, 40m, now),
            CreateCourt("Teniski teren 1", tenis, centerMo, 25m, now),
            CreateCourt("Padel teren A", padel, centerSa, 30m, now),
            CreateCourt("Badminton teren 1", badminton, centerSa, 20m, now));

        await db.SaveChangesAsync();
    }

    private static Court CreateCourt(string name, Sport sport, SportCenter center, decimal price, DateTime now)
    {
        var court = new Court
        {
            Name = name,
            Sport = sport,
            SportCenter = center,
            PricePerHour = price,
            IsActive = true,
            CreatedAt = now
        };

        court.Images.Add(new CourtImage
        {
            ImageData = PlaceholderImage,
            ContentType = "image/png",
            IsPrimary = true,
            CreatedAt = now
        });

        for (var day = 0; day < 7; day++)
        {
            court.WorkingHours.Add(new CourtWorkingHours
            {
                DayOfWeek = (DayOfWeek)day,
                OpenTime = new TimeOnly(8, 0),
                CloseTime = new TimeOnly(22, 0),
                CreatedAt = now
            });
        }

        return court;
    }
}
