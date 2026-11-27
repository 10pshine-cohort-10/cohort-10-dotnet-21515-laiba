# Runs the full verification suite, stopping at the first failure.
# Works on a partial checkout: a step whose project (backend/ or frontend/)
# doesn't exist yet at this revision is skipped rather than failing.
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

function Write-SkipNotice {
    param([string]$Name, [string]$Reason)
    Write-Host "SKIPPED: $Name - $Reason"
    $script:skipped.Add($Name)
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$dotnet = if ($env:DOTNET_EXE) { $env:DOTNET_EXE } else { "dotnet" }

$backendAvailable = Test-Path "backend/TaskManagement.sln"
$frontendAvailable = Test-Path "frontend/package.json"

$ran = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

if ($backendAvailable) {
    Invoke-Checked "dotnet build" { & $dotnet build backend/TaskManagement.sln }
    $ran.Add("dotnet build")

    Invoke-Checked "dotnet test" { & $dotnet test backend/TaskManagement.sln }
    $ran.Add("dotnet test")
}
else {
    Write-SkipNotice "dotnet build" "backend/TaskManagement.sln not found"
    Write-SkipNotice "dotnet test" "backend/TaskManagement.sln not found"
}

if ($frontendAvailable) {
    Invoke-Checked "npm run lint" { npm --prefix frontend run lint }
    $ran.Add("npm run lint")

    Invoke-Checked "npm run test" { npm --prefix frontend run test }
    $ran.Add("npm run test")

    Invoke-Checked "npm run build" { npm --prefix frontend run build }
    $ran.Add("npm run build")
}
else {
    Write-SkipNotice "npm run lint" "frontend/package.json not found"
    Write-SkipNotice "npm run test" "frontend/package.json not found"
    Write-SkipNotice "npm run build" "frontend/package.json not found"
}

Write-Host ""
Write-Host "==> Summary"
foreach ($s in $ran) { Write-Host "  RAN:     $s" }
foreach ($s in $skipped) { Write-Host "  SKIPPED: $s" }

if ($ran.Count -eq 0) {
    Write-Host ""
    Write-Warning "No checks ran - backend/ and frontend/ are both missing at this revision."
    exit 1
}

Write-Host ""
Write-Host "All checks passed."
