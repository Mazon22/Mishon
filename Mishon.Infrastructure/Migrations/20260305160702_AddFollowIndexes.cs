using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mishon.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddFollowIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Follows_FollowerId_FollowingId",
                table: "Follows",
                columns: new[] { "FollowerId", "FollowingId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Follows_FollowerId_FollowingId",
                table: "Follows");
        }
    }
}
