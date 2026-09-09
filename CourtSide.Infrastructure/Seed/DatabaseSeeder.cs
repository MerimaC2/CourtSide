using CourtSide.Core.Entities;
using CourtSide.Core.Entities.Identity;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Helpers;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace CourtSide.Infrastructure.Seed;

/// <summary>Seeds roles, test users and reference/domain data (idempotent) at startup.</summary>
public static class DatabaseSeeder
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        var db = services.GetRequiredService<DatabaseContext>();
        var userManager = services.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = services.GetRequiredService<RoleManager<ApplicationRole>>();

        await SeedRolesAsync(roleManager);
        await SeedUsersAsync(userManager);
        await SeedDomainAsync(db);
        await SeedNewsAsync(db);
        await SeedActivityAsync(db, userManager);
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
        // Extra clients so reservation history spans several users, which the recommender
        // needs in order to find similarities between them.
        await EnsureUserAsync(userManager, "amina", "amina@courtside.local", "Amina", "Hodžić", "test", Roles.User);
        await EnsureUserAsync(userManager, "tarik", "tarik@courtside.local", "Tarik", "Begić", "test", Roles.User);
        await EnsureUserAsync(userManager, "lejla", "lejla@courtside.local", "Lejla", "Softić", "test", Roles.User);
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

        // The demo accounts are documented with the password `test`, which is shorter than the
        // six characters Identity now requires of real users. Hashing it here bypasses only the
        // password validators for these fixed accounts; registration and password changes keep
        // the rule. The hash is produced the same way Identity would, so sign-in is unaffected.
        user.PasswordHash = userManager.PasswordHasher.HashPassword(user, password);

        var result = await userManager.CreateAsync(user);
        if (!result.Succeeded)
        {
            // Silently skipping would leave a fresh database with no way in, and the cause would
            // only show up as a failed login much later.
            throw new InvalidOperationException(
                $"Seed naloga '{username}' nije uspio: {string.Join("; ", result.Errors.Select(e => e.Description))}");
        }

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
            CreateCourt("Futsal teren 1", futsal, centerMo, 40m, SeedImages.Futsal, now),
            CreateCourt("Teniski teren 1", tenis, centerMo, 25m, SeedImages.Tenis, now),
            CreateCourt("Padel teren A", padel, centerSa, 30m, SeedImages.Padel, now),
            CreateCourt("Badminton teren 1", badminton, centerSa, 20m, SeedImages.Badminton, now));

        await db.SaveChangesAsync();
    }

    /// <summary>
    /// Booking history so the app has something to show on first run: reservations across every
    /// status, their payments, reviews on the finished ones and the matching notifications.
    /// The recommender also needs real history before it can suggest anything.
    /// </summary>
    private static async Task SeedActivityAsync(DatabaseContext db, UserManager<ApplicationUser> userManager)
    {
        if (await db.Reservations.AnyAsync()) return;

        var courts = await db.Courts.OrderBy(c => c.Id).ToListAsync();
        if (courts.Count < 4) return;

        var clients = new List<ApplicationUser>();
        foreach (var name in new[] { "mobile", "amina", "tarik", "lejla" })
        {
            var user = await userManager.FindByNameAsync(name);
            if (user is not null) clients.Add(user);
        }
        if (clients.Count < 4) return;

        var now = DateTime.UtcNow;
        var today = DateOnly.FromDateTime(now);
        var usedNumbers = new HashSet<string>();

        string NextNumber()
        {
            string number;
            do { number = ReservationNumber.Generate(); } while (!usedNumbers.Add(number));
            return number;
        }

        Reservation Book(ApplicationUser client, Court court, int dayOffset, int hour,
            ReservationStatus status, PaymentMethod method, PaymentStatus paymentStatus)
        {
            var date = today.AddDays(dayOffset);
            var createdAt = now.AddDays(dayOffset - 2);
            var price = court.PricePerHour;

            var reservation = new Reservation
            {
                ReservationNumber = NextNumber(),
                ClientId = client.Id,
                CourtId = court.Id,
                Date = date,
                StartTime = new TimeOnly(hour, 0),
                EndTime = new TimeOnly(hour + 1, 0),
                TotalPrice = price,
                Status = status,
                ContactName = client.FirstName + " " + client.LastName,
                ContactPhone = "061 234 567",
                CreatedAt = createdAt,
                Payment = new Payment
                {
                    Method = method,
                    Amount = price,
                    Currency = "BAM",
                    Status = paymentStatus,
                    PaidAt = paymentStatus == PaymentStatus.Completed ? createdAt : null,
                    CreatedAt = createdAt
                }
            };

            if (status is ReservationStatus.Confirmed or ReservationStatus.Completed)
                reservation.ConfirmedAt = createdAt.AddHours(1);

            if (status == ReservationStatus.Completed)
                reservation.CompletedAt = date.ToDateTime(new TimeOnly(hour + 1, 0));

            if (status == ReservationStatus.Cancelled)
            {
                reservation.CancelledAt = createdAt.AddHours(2);
                reservation.CancellationReason = "Spriječen dolazak zbog poslovnih obaveza.";
            }

            return reservation;
        }

        var reservations = new List<Reservation>
        {
            // Finished bookings — these drive the ratings and give the recommender its history.
            Book(clients[0], courts[0], -21, 18, ReservationStatus.Completed, PaymentMethod.Stripe, PaymentStatus.Completed),
            Book(clients[0], courts[1], -14, 19, ReservationStatus.Completed, PaymentMethod.Cash, PaymentStatus.Completed),
            Book(clients[0], courts[0], -7, 20, ReservationStatus.Completed, PaymentMethod.Stripe, PaymentStatus.Completed),
            Book(clients[1], courts[0], -18, 17, ReservationStatus.Completed, PaymentMethod.Cash, PaymentStatus.Completed),
            Book(clients[1], courts[1], -11, 18, ReservationStatus.Completed, PaymentMethod.Stripe, PaymentStatus.Completed),
            Book(clients[2], courts[2], -16, 19, ReservationStatus.Completed, PaymentMethod.Stripe, PaymentStatus.Completed),
            Book(clients[2], courts[3], -9, 20, ReservationStatus.Completed, PaymentMethod.Cash, PaymentStatus.Completed),
            Book(clients[3], courts[2], -12, 17, ReservationStatus.Completed, PaymentMethod.Cash, PaymentStatus.Completed),
            Book(clients[3], courts[1], -5, 18, ReservationStatus.Completed, PaymentMethod.Stripe, PaymentStatus.Completed),

            // One cancelled booking, so every status appears in the list and the report.
            Book(clients[0], courts[3], -4, 16, ReservationStatus.Cancelled, PaymentMethod.Cash, PaymentStatus.Pending),

            // Upcoming bookings: confirmed, and still awaiting an administrator's confirmation.
            Book(clients[0], courts[1], 3, 18, ReservationStatus.Confirmed, PaymentMethod.Stripe, PaymentStatus.Completed),
            Book(clients[0], courts[2], 6, 19, ReservationStatus.Pending, PaymentMethod.Cash, PaymentStatus.Pending),
            Book(clients[1], courts[0], 4, 20, ReservationStatus.Confirmed, PaymentMethod.Cash, PaymentStatus.Pending),
            Book(clients[2], courts[3], 5, 17, ReservationStatus.Pending, PaymentMethod.Stripe, PaymentStatus.Pending),
        };

        db.Reservations.AddRange(reservations);
        await db.SaveChangesAsync();

        var comments = new (int Rating, string Comment)[]
        {
            (5, "Teren u odličnom stanju, osvjetljenje odlično."),
            (4, "Sve pohvale, jedino je parking znao biti pun."),
            (5, "Redovno dolazimo, uvijek čisto i uredno."),
            (4, "Dobra podloga, preporučujem."),
            (3, "Solidno, ali svlačionice bi mogle biti bolje."),
            (5, "Najbolji teren u gradu."),
        };

        var completed = reservations
            .Where(r => r.Status == ReservationStatus.Completed)
            .Take(comments.Length)
            .ToList();

        for (var i = 0; i < completed.Count; i++)
        {
            var reservation = completed[i];
            db.CourtReviews.Add(new CourtReview
            {
                CourtId = reservation.CourtId,
                UserId = reservation.ClientId,
                ReservationId = reservation.Id,
                Rating = comments[i].Rating,
                Comment = comments[i].Comment,
                CreatedAt = reservation.CompletedAt ?? reservation.CreatedAt
            });
        }

        // The notifications these bookings would have produced while they were happening.
        foreach (var reservation in reservations)
        {
            var shortNumber = ReservationNumber.Short(reservation.ReservationNumber);

            db.Notifications.Add(new Notification
            {
                UserId = reservation.ClientId,
                Type = NotificationType.ReservationCreated,
                Title = "Rezervacija kreirana",
                Text = "Vaša rezervacija " + shortNumber + " je kreirana i čeka potvrdu.",
                IsRead = true,
                CreatedAt = reservation.CreatedAt
            });

            switch (reservation.Status)
            {
                case ReservationStatus.Completed:
                    db.Notifications.Add(new Notification
                    {
                        UserId = reservation.ClientId,
                        Type = NotificationType.ReservationCompleted,
                        Title = "Rezervacija završena",
                        Text = "Vaša rezervacija " + shortNumber + " je završena. Možete ocijeniti teren.",
                        IsRead = false,
                        CreatedAt = reservation.CompletedAt ?? reservation.CreatedAt
                    });
                    break;

                case ReservationStatus.Cancelled:
                    db.Notifications.Add(new Notification
                    {
                        UserId = reservation.ClientId,
                        Type = NotificationType.ReservationCancelled,
                        Title = "Rezervacija otkazana",
                        Text = "Rezervacija " + shortNumber + " je otkazana. Razlog: " + reservation.CancellationReason,
                        IsRead = false,
                        CreatedAt = reservation.CancelledAt ?? reservation.CreatedAt
                    });
                    break;

                case ReservationStatus.Confirmed:
                    db.Notifications.Add(new Notification
                    {
                        UserId = reservation.ClientId,
                        Type = NotificationType.ReservationConfirmed,
                        Title = "Rezervacija potvrđena",
                        Text = "Vaša rezervacija " + shortNumber + " je potvrđena.",
                        IsRead = false,
                        CreatedAt = reservation.ConfirmedAt ?? reservation.CreatedAt
                    });
                    break;
            }
        }

        await db.SaveChangesAsync();
    }

    private static async Task SeedNewsAsync(DatabaseContext db)
    {
        if (await db.News.AnyAsync()) return;

        var now = DateTime.UtcNow;
        db.News.AddRange(
            new News
            {
                Title = "Produženo radno vrijeme vikendom",
                Text = "Od ovog mjeseca svi tereni rade do 22h i subotom i nedjeljom. " +
                       "Termine možete rezervisati kroz aplikaciju kao i obično.",
                PublishedAt = now.AddDays(-3),
                ImageData = SeedImages.News,
                ImageContentType = "image/jpeg",
                CreatedAt = now.AddDays(-3)
            },
            new News
            {
                Title = "Novi padel tereni u Sarajevu",
                Text = "Padel Arena Sarajevo dobila je dva nova terena. Rezervacije su otvorene.",
                PublishedAt = now.AddDays(-10),
                ImageData = SeedImages.Padel,
                ImageContentType = "image/jpeg",
                CreatedAt = now.AddDays(-10)
            },
            new News
            {
                Title = "Popust za jutarnje termine",
                Text = "Termini prije 10h su 20% jeftiniji radnim danima tokom cijele sezone.",
                PublishedAt = now.AddDays(-21),
                ImageData = SeedImages.Tenis,
                ImageContentType = "image/jpeg",
                CreatedAt = now.AddDays(-21)
            });

        await db.SaveChangesAsync();
    }

    private static Court CreateCourt(string name, Sport sport, SportCenter center, decimal price,
        byte[] photo, DateTime now)
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
            ImageData = photo,
            ContentType = "image/jpeg",
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
