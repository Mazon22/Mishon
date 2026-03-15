using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mishon.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddForwardedMessages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ForwardedFromMessageId",
                table: "Messages",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ForwardedFromUserId",
                table: "Messages",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Messages_ForwardedFromMessageId",
                table: "Messages",
                column: "ForwardedFromMessageId");

            migrationBuilder.CreateIndex(
                name: "IX_Messages_ForwardedFromUserId",
                table: "Messages",
                column: "ForwardedFromUserId");

            migrationBuilder.AddForeignKey(
                name: "FK_Messages_Messages_ForwardedFromMessageId",
                table: "Messages",
                column: "ForwardedFromMessageId",
                principalTable: "Messages",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Messages_Users_ForwardedFromUserId",
                table: "Messages",
                column: "ForwardedFromUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Messages_Messages_ForwardedFromMessageId",
                table: "Messages");

            migrationBuilder.DropForeignKey(
                name: "FK_Messages_Users_ForwardedFromUserId",
                table: "Messages");

            migrationBuilder.DropIndex(
                name: "IX_Messages_ForwardedFromMessageId",
                table: "Messages");

            migrationBuilder.DropIndex(
                name: "IX_Messages_ForwardedFromUserId",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "ForwardedFromMessageId",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "ForwardedFromUserId",
                table: "Messages");
        }
    }
}
