<#
  Creates LearnInsuranceDB (if missing) and applies every script in order:
  schema -> tables -> functions (helpers, generated CRUD, hand-written) -> indexes -> seed.
  All scripts are idempotent, so this can be re-run safely.

  Usage:  powershell -File LearnDB/setup.ps1            (apply everything)
          powershell -File LearnDB/setup.ps1 -Reset     (DROP the schema first - destroys data!)
  Password: -Password, or the PGPASSWORD environment variable (local-dev default below).
#>
param(
  [string]$DbHost = 'localhost',
  [int]$Port = 5432,
  [string]$Database = 'LearnInsuranceDB',
  [string]$User = 'postgres',
  [string]$Password = $(if ($env:PGPASSWORD) { $env:PGPASSWORD } else { '284228' }),
  [switch]$Reset
)
$ErrorActionPreference = 'Stop'
$env:PGPASSWORD = $Password
$psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
if (-not $psql) { $psql = (Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' | Sort-Object FullName -Descending | Select-Object -First 1).FullName }
$base = @('-h', $DbHost, '-p', $Port, '-U', $User, '-v', 'ON_ERROR_STOP=1', '-q')

$exists = & $psql @base -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$Database'"
if (-not $exists) {
  Write-Host "Creating database $Database"
  # Windows PowerShell 5.1 strips embedded double quotes from native args, so go through a file
  # (the quoted identifier keeps the mixed-case name exactly as in the connection string).
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp -Value "CREATE DATABASE `"$Database`" ENCODING 'UTF8';" -Encoding ascii
  & $psql @base -d postgres -f $tmp
  Remove-Item -LiteralPath $tmp -Force
}
if ($Reset) {
  Write-Host 'Dropping schema learninsurancedb'
  & $psql @base -d $Database -c 'DROP SCHEMA IF EXISTS learninsurancedb CASCADE'
}

$root = $PSScriptRoot
foreach ($folder in 'schema', 'tables', 'functions', 'indexes', 'seed') {
  $files = Get-ChildItem -Path (Join-Path $root $folder) -Filter *.sql -Recurse | Sort-Object FullName
  foreach ($f in $files) {
    Write-Host ("  [{0}] {1}" -f $folder, $f.Name)
    & $psql @base -d $Database -f $f.FullName
    if ($LASTEXITCODE -ne 0) { throw "Script failed: $($f.FullName)" }
  }
}
Write-Host 'LearnInsuranceDB is ready.' -ForegroundColor Green
