# Runs local SonarQube analysis for backend + frontend.
# Requires: dotnet-sonarscanner installed, SONAR_TOKEN set, a reachable Sonar server (SONAR_HOST_URL).
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

if (-not $env:SONAR_TOKEN) {
    throw "SONAR_TOKEN env var must be set"
}
$sonarHostUrl = if ($env:SONAR_HOST_URL) { $env:SONAR_HOST_URL } else { "http://localhost:9000" }
$projectKey = "cohort-10-dotnet-21515-laiba"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

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

Invoke-Checked "Backend: build" { dotnet build backend/TaskManagement.sln }
Invoke-Checked "Backend: test with coverage" {
    dotnet test backend/TaskManagement.sln --collect:"XPlat Code Coverage;Format=opencover"
}

Invoke-Checked "Frontend: tests with lcov coverage" {
    npm --prefix frontend run test -- --coverage
}

Invoke-Checked "Backend: dotnet-sonarscanner end" {
    dotnet-sonarscanner end /d:sonar.token="$env:SONAR_TOKEN"
}

Write-Host "Done. Frontend lcov report: frontend/coverage/lcov.info"
