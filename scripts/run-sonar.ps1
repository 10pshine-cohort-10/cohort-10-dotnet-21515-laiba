# Runs local SonarQube analysis for backend + frontend.
# Requires: dotnet-sonarscanner installed (for backend-only/combined checkouts)
# and/or the standalone Sonar Scanner CLI (for frontend-only checkouts),
# SONAR_TOKEN set, a reachable Sonar server (SONAR_HOST_URL).
#
# Works on a partial checkout:
#   - backend-only or combined: dotnet-sonarscanner begin -> dotnet build ->
#     dotnet test -> (frontend coverage, if present) -> end. Unchanged from
#     before - dotnet-sonarscanner always wraps a real dotnet build/test pass.
#   - frontend-only (no backend/): dotnet-sonarscanner is NOT run - it has no
#     .NET build to wrap. The standalone `sonar-scanner` CLI is used instead
#     if it's installed; if it isn't, the analysis step is skipped with an
#     explicit message rather than silently doing nothing.
#   - neither present: the whole run is skipped.
param()
$ErrorActionPreference = "Stop"

# $ErrorActionPreference only catches terminating PowerShell errors - a native
# command (dotnet, npm, dotnet-sonarscanner, sonar-scanner) that exits non-zero
# does NOT throw on its own, so every call below is checked via this helper.
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

$projectKey = "cohort-10-dotnet-21515-laiba"

$ran = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

if (-not $backendAvailable -and -not $frontendAvailable) {
    Write-SkipNotice "dotnet-sonarscanner begin" "backend/TaskManagement.sln and frontend/package.json not found"
    Write-SkipNotice "dotnet build" "backend/TaskManagement.sln not found"
    Write-SkipNotice "dotnet test" "backend/TaskManagement.sln not found"
    Write-SkipNotice "npm run test -- --coverage" "frontend/package.json not found"
    Write-SkipNotice "dotnet-sonarscanner end" "backend/TaskManagement.sln and frontend/package.json not found"
}
elseif ($backendAvailable) {
    # Backend-only or combined checkout: unchanged begin -> build -> test -> end
    # sequence. dotnet-sonarscanner always wraps a real dotnet build here.
    if (-not $env:SONAR_TOKEN) {
        throw "SONAR_TOKEN env var must be set"
    }
    $sonarHostUrl = if ($env:SONAR_HOST_URL) { $env:SONAR_HOST_URL } else { "http://localhost:9000" }

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

    Invoke-Checked "Backend: build" { dotnet build backend/TaskManagement.sln }
    $ran.Add("dotnet build")

    Invoke-Checked "Backend: test with coverage" {
        dotnet test backend/TaskManagement.sln --collect:"XPlat Code Coverage;Format=opencover"
    }
    $ran.Add("dotnet test")

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
else {
    # Frontend-only checkout: no .NET build exists, so dotnet-sonarscanner
    # begin/end must NOT run (it only wraps a real dotnet build/test pass).
    Write-SkipNotice "dotnet-sonarscanner begin" "backend/TaskManagement.sln not found - dotnet-sonarscanner cannot run without a .NET build"
    Write-SkipNotice "dotnet build" "backend/TaskManagement.sln not found"
    Write-SkipNotice "dotnet test" "backend/TaskManagement.sln not found"
    Write-SkipNotice "dotnet-sonarscanner end" "backend/TaskManagement.sln not found - dotnet-sonarscanner cannot run without a .NET build"

    $scannerCmd = Get-Command sonar-scanner -ErrorAction SilentlyContinue
    if ($scannerCmd) {
        if (-not $env:SONAR_TOKEN) {
            throw "SONAR_TOKEN env var must be set"
        }
        $sonarHostUrl = if ($env:SONAR_HOST_URL) { $env:SONAR_HOST_URL } else { "http://localhost:9000" }

        Invoke-Checked "Frontend: tests with lcov coverage" {
            npm --prefix frontend run test -- --coverage
        }
        $ran.Add("npm run test -- --coverage")

        # Reusing the same project key/exclusions/token/host settings as the
        # dotnet-sonarscanner begin call above, as -D args (no properties file -
        # see the sonarqube skill/README for why).
        Invoke-Checked "Frontend: standalone sonar-scanner analysis" {
            & $scannerCmd `
              -Dsonar.projectKey="$projectKey" `
              -Dsonar.sources="frontend/src" `
              -Dsonar.host.url="$sonarHostUrl" `
              -Dsonar.token="$env:SONAR_TOKEN" `
              -Dsonar.exclusions="**/bin/**,**/obj/**,**/Migrations/**,**/node_modules/**,**/dist/**,**/*.g.cs,**/*.g.i.cs" `
              -Dsonar.coverage.exclusions="**/Migrations/**,**/Program.cs,frontend/src/**/*.test.*,frontend/src/**/*.spec.*" `
              -Dsonar.javascript.lcov.reportPaths="frontend/coverage/lcov.info" `
              -Dsonar.typescript.lcov.reportPaths="frontend/coverage/lcov.info"
        }
        $ran.Add("sonar-scanner")
    }
    else {
        Write-SkipNotice "npm run test -- --coverage" "no SonarQube scanner available for a frontend-only checkout (see below)"
        Write-SkipNotice "sonar-scanner" "standalone Sonar Scanner CLI not found on PATH - dotnet-sonarscanner cannot analyze a frontend-only checkout without a .NET build. Install the Sonar Scanner CLI to enable analysis here, or add a backend checkout."
    }
}

Write-Host ""
Write-Host "==> Summary"
foreach ($s in $ran) { Write-Host "  RAN:     $s" }
foreach ($s in $skipped) { Write-Host "  SKIPPED: $s" }

if ($ran.Count -eq 0) {
    Write-Host ""
    Write-Warning "No SonarQube analysis ran - see the SKIPPED lines above for why."
    exit 1
}

Write-Host ""
Write-Host "Done."
