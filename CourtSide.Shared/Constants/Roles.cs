namespace CourtSide.Shared.Constants;

/// <summary>Role names. Must match the roles seeded into the database and used in [Authorize].</summary>
public static class Roles
{
    public const string Admin = "Admin";
    public const string User = "User";
}
