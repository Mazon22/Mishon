param(
  [Parameter(Mandatory = $true)]
  [string]$BackupPath,
  [string]$Database = "mishon",
  [string]$User = "mishon",
  [string]$Service = "postgres"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BackupPath)) {
  throw "Backup file not found: $BackupPath"
}

Get-Content -Raw -LiteralPath $BackupPath | docker compose exec -T $Service psql -U $User -d $Database

Write-Host "PostgreSQL restore completed from $BackupPath"
