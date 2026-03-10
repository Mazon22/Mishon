using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mishon.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddProfileMediaLayout : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "AvatarUrl",
                table: "Users",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);

            migrationBuilder.AddColumn<double>(
                name: "AvatarOffsetX",
                table: "Users",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "AvatarOffsetY",
                table: "Users",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "AvatarScale",
                table: "Users",
                type: "double precision",
                nullable: false,
                defaultValue: 1.0);

            migrationBuilder.AddColumn<double>(
                name: "BannerOffsetX",
                table: "Users",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "BannerOffsetY",
                table: "Users",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "BannerScale",
                table: "Users",
                type: "double precision",
                nullable: false,
                defaultValue: 1.0);

            migrationBuilder.AddColumn<string>(
                name: "BannerUrl",
                table: "Users",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AvatarOffsetX",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "AvatarOffsetY",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "AvatarScale",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "BannerOffsetX",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "BannerOffsetY",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "BannerScale",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "BannerUrl",
                table: "Users");

            migrationBuilder.AlterColumn<string>(
                name: "AvatarUrl",
                table: "Users",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(500)",
                oldMaxLength: 500,
                oldNullable: true);
        }
    }
}
