# Runs local SonarQube analysis for backend + frontend.
# Requires: dotnet-sonarscanner installed, SONAR_TOKEN set, a reachable Sonar server (SONAR_HOST_URL).
# Works on a partial checkout: a step whose project (backend/ or frontend/)
# doesn't exist yet at this revision is skipped rather than failing. If
# neither exists, the whole sonar run (including begin/end) is skipped.
param()
$ErrorActionPreference = "Stop"

# $ErrorActionPreference only catches terminating PowerShell errors - a native
# command (dotnet, npm, dotnet-sonarscanner) that exits non-zero does NOT throw
# on its own, so every call below is checked explicitly via this helper.
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

$backendAvailable = Test-Path "backend/TaskManagement.sln"
$frontendAvailable = Test-Path "frontend/package.json"

$ran = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

if (-not $backendAvailable -and -not $frontendAvailable) {
    Write-SkipNotice "dotnet-sonarscanner begin" "backend/TaskManagement.sln and frontend/package.json not found"
    Write-SkipNotice "dotnet build" "backend/TaskManagement.sln not found"
    Write-SkipNotice "dotnet test" "backend/TaskManagement.sln not found"
    Write-SkipNotice "npm run test -- --coverage" "frontend/package.json not found"
    Write-SkipNotice "dotnet-sonarscanner end" "backend/TaskManagement.sln and frontend/package.json not found"
}
else {
    # Only required once we know at least one side of the analysis will run.
    if (-not $env:SONAR_TOKEN) {
        throw "SONAR_TOKEN env var must be set"
    }
    $sonarHostUrl = if ($env:SONAR_HOST_URL) { $env:SONAR_HOST_URL } else { "http://localhost:9000" }
    $projectKey = "cohort-10-dotnet-21515-laiba"

    # dotnet-sonarscanner does not read sonar-project.properties - every setting it
    # needs has to be passed as a /d: argument here.
    Invoke-Checked "Backend: dotnet-sonarscanner begin" {
        dotnet-sonarscanner begin `
          /k:"$projectKey" `
          /d:sonar.host.url="$sonarHostUrl" `
          /d:sonar.token="$env:SONAR_TOKEN" `
          /d:sonar.exclusions="**/bin/**,**/obj/**,**/Migrations/**,**/node_modules/**,**/dist/**,**/*.g.cs,**/*.g.i.cs" `
          /d:sonar.coverage.exclusions="**/Migrations/**,**/Program.cs,frontend/src/**/*.test.*,frontend/src/**/*.spec.*" `
          /d:sonar.cs.opencover.reportsPaths="backend/tests/**/coverage.opencover.xml" `
          /d:sonar.javascript.lcov.reportPaths="frontend/coverage/lcov.info" `
          /d:sonar.typescript.lcov.reportPaths="frontend/coverage/lcov.info"
    }
    $ran.Add("dotnet-sonarscanner begin")

    if ($backendAvailable) {
        Invoke-Checked "Backend: build" { dotnet build backend/TaskManagement.sln }
        $ran.Add("dotnet build")

        Invoke-Checked "Backend: test with coverage" {
            dotnet test backend/TaskManagement.sln --collect:"XPlat Code Coverage;Format=opencover"
        }
        $ran.Add("dotnet test")
    }
    else {
        Write-SkipNotice "dotnet build" "backend/TaskManagement.sln not found"
        Write-SkipNotice "dotnet test" "backend/TaskManagement.sln not found"
    }

    if ($frontendAvailable) {
        Invoke-Checked "Frontend: tests with lcov coverage" {
            npm --prefix frontend run test -- --coverage
        }
        $ran.Add("npm run test -- --coverage")
    }
    else {
        Write-SkipNotice "npm run test -- --coverage" "frontend/package.json not found"
    }

    Invoke-Checked "Backend: dotnet-sonarscanner end" {
        dotnet-sonarscanner end /d:sonar.token="$env:SONAR_TOKEN"
    }
    $ran.Add("dotnet-sonarscanner end")
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
Write-Host "Done. Frontend lcov report: frontend/coverage/lcov.info"
