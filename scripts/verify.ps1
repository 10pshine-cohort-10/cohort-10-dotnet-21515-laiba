# Runs the full verification suite, stopping at the first failure.
param()
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$dotnet = if ($env:DOTNET_EXE) { $env:DOTNET_EXE } else { "dotnet" }

Write-Host "==> dotnet build"
& $dotnet build backend/TaskManagement.sln

Write-Host "==> dotnet test"
& $dotnet test backend/TaskManagement.sln

Write-Host "==> npm run lint"
npm --prefix frontend run lint

Write-Host "==> npm run test"
npm --prefix frontend run test

Write-Host "==> npm run build"
npm --prefix frontend run build

Write-Host "All checks passed."
