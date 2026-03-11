using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mishon.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddUserAboutMe : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AboutMe",
                table: "Users",
                type: "character varying(280)",
                maxLength: 280,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AboutMe",
                table: "Users");
        }
    }
}
