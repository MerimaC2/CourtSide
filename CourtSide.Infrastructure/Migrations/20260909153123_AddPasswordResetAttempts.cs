using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CourtSide.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPasswordResetAttempts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Attempts",
                table: "PasswordResetCodes",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Attempts",
                table: "PasswordResetCodes");
        }
    }
}
