using Microsoft.AspNetCore.Identity;

namespace CourtSide.Core.Entities.Identity;

public class ApplicationRole : IdentityRole<int>
{
    public string? Description { get; set; }
}
