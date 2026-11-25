# Runs the full verification suite, stopping at the first failure.
param()
$ErrorActionPreference = "Stop"

# $ErrorActionPreference only catches terminating PowerShell errors - a native
# command (dotnet, npm) that exits non-zero does NOT throw on its own, so every
# call below is checked explicitly via this helper.
function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][scriptblock]$Command
    )
    Write-Host "==> $Description"
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "FAILED: $Description (exit code $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$dotnet = if ($env:DOTNET_EXE) { $env:DOTNET_EXE } else { "dotnet" }

Invoke-Checked "dotnet build" { & $dotnet build backend/TaskManagement.sln }
Invoke-Checked "dotnet test" { & $dotnet test backend/TaskManagement.sln }
Invoke-Checked "npm run lint" { npm --prefix frontend run lint }
Invoke-Checked "npm run test" { npm --prefix frontend run test }
Invoke-Checked "npm run build" { npm --prefix frontend run build }

Write-Host "All checks passed."
