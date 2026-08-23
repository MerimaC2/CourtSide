using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CourtSide.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddReservationCompletedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CompletedAt",
                table: "Reservations",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CompletedAt",
                table: "Reservations");
        }
    }
}
