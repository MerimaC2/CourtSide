using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace CourtSide.Infrastructure;

/// <summary>
/// Lets <c>dotnet ef</c> create the context at design time (migrations) without running the API.
/// Uses CONNECTION_STRING if set, otherwise local SQL Server LocalDB.
/// </summary>
public class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<DatabaseContext>
{
    public DatabaseContext CreateDbContext(string[] args)
    {
        var connectionString =
            Environment.GetEnvironmentVariable("CONNECTION_STRING")
            ?? "Server=(localdb)\\MSSQLLocalDB;Database=180099;Trusted_Connection=True;TrustServerCertificate=True;";

        var options = new DbContextOptionsBuilder<DatabaseContext>()
            .UseSqlServer(connectionString)
            .Options;

        return new DatabaseContext(options);
    }
}
