using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CourtSide.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentRefundTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "PaidById",
                table: "Payments",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RefundConfirmedById",
                table: "Payments",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RefundFailureReason",
                table: "Payments",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "RefundRequestedAt",
                table: "Payments",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StripeRefundId",
                table: "Payments",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PaidById",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "RefundConfirmedById",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "RefundFailureReason",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "RefundRequestedAt",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "StripeRefundId",
                table: "Payments");
        }
    }
}
