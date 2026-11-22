# Runs local SonarQube analysis for backend + frontend.
# Requires: dotnet-sonarscanner installed, SONAR_TOKEN set, a reachable Sonar server (SONAR_HOST_URL).
param()
$ErrorActionPreference = "Stop"

if (-not $env:SONAR_TOKEN) {
    throw "SONAR_TOKEN env var must be set"
}
$sonarHostUrl = if ($env:SONAR_HOST_URL) { $env:SONAR_HOST_URL } else { "http://localhost:9000" }
$projectKey = "cohort-10-dotnet-21515-laiba"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

Write-Host "==> Backend: dotnet-sonarscanner begin"
dotnet-sonarscanner begin `
  /k:"$projectKey" `
  /d:sonar.host.url="$sonarHostUrl" `
  /d:sonar.token="$env:SONAR_TOKEN" `
  /d:sonar.cs.opencover.reportsPaths="backend/tests/**/coverage.opencover.xml"

Write-Host "==> Backend: build + test with coverage"
dotnet build backend/TaskManagement.sln
dotnet test backend/TaskManagement.sln --collect:"XPlat Code Coverage;Format=opencover"

Write-Host "==> Backend: dotnet-sonarscanner end"
dotnet-sonarscanner end /d:sonar.token="$env:SONAR_TOKEN"

Write-Host "==> Frontend: tests with lcov coverage"
npm --prefix frontend run test -- --coverage

Write-Host "Done. Frontend lcov report: frontend/coverage/lcov.info"
