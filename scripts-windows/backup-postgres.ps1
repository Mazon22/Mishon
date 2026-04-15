param(
  [string]$OutputDir = ".\\backups",
  [string]$Database = "mishon",
  [string]$User = "mishon",
  [string]$Service = "postgres"
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $OutputDir "mishon-$timestamp.sql"

docker compose exec -T $Service pg_dump -U $User -d $Database --clean --if-exists > $outputPath

Write-Host "PostgreSQL backup created at $outputPath"
