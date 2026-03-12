using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Mishon.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddChatManagementAndBlocks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Conversations_UserBId",
                table: "Conversations");

            migrationBuilder.AddColumn<bool>(
                name: "DeletedForUserA",
                table: "Messages",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "DeletedForUserB",
                table: "Messages",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "UserAArchived",
                table: "Conversations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "UserADeleted",
                table: "Conversations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "UserAFavorite",
                table: "Conversations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "UserAMuted",
                table: "Conversations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "UserAPinOrder",
                table: "Conversations",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "UserBArchived",
                table: "Conversations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "UserBDeleted",
                table: "Conversations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "UserBFavorite",
                table: "Conversations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "UserBMuted",
                table: "Conversations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "UserBPinOrder",
                table: "Conversations",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "UserBlocks",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    BlockerId = table.Column<int>(type: "integer", nullable: false),
                    BlockedUserId = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserBlocks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserBlocks_Users_BlockedUserId",
                        column: x => x.BlockedUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserBlocks_Users_BlockerId",
                        column: x => x.BlockerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Conversations_UserAId_UserAPinOrder",
                table: "Conversations",
                columns: new[] { "UserAId", "UserAPinOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_Conversations_UserBId_UserBPinOrder",
                table: "Conversations",
                columns: new[] { "UserBId", "UserBPinOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_UserBlocks_BlockedUserId_CreatedAt",
                table: "UserBlocks",
                columns: new[] { "BlockedUserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_UserBlocks_BlockerId_BlockedUserId",
                table: "UserBlocks",
                columns: new[] { "BlockerId", "BlockedUserId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserBlocks");

            migrationBuilder.DropIndex(
                name: "IX_Conversations_UserAId_UserAPinOrder",
                table: "Conversations");

            migrationBuilder.DropIndex(
                name: "IX_Conversations_UserBId_UserBPinOrder",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "DeletedForUserA",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "DeletedForUserB",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "UserAArchived",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserADeleted",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserAFavorite",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserAMuted",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserAPinOrder",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserBArchived",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserBDeleted",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserBFavorite",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserBMuted",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "UserBPinOrder",
                table: "Conversations");

            migrationBuilder.CreateIndex(
                name: "IX_Conversations_UserBId",
                table: "Conversations",
                column: "UserBId");
        }
    }
}
