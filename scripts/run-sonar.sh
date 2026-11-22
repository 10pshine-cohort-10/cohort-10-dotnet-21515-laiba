#!/usr/bin/env bash
# Runs local SonarQube analysis for backend + frontend.
# Requires: dotnet-sonarscanner installed, SONAR_TOKEN set, a reachable Sonar server (SONAR_HOST_URL).
set -euo pipefail

: "${SONAR_TOKEN:?SONAR_TOKEN env var must be set}"
SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
PROJECT_KEY="cohort-10-dotnet-21515-laiba"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "==> Backend: dotnet-sonarscanner begin"
dotnet-sonarscanner begin \
  /k:"$PROJECT_KEY" \
  /d:sonar.host.url="$SONAR_HOST_URL" \
  /d:sonar.token="$SONAR_TOKEN" \
  /d:sonar.cs.opencover.reportsPaths="backend/tests/**/coverage.opencover.xml"

echo "==> Backend: build + test with coverage"
dotnet build backend/TaskManagement.sln
dotnet test backend/TaskManagement.sln --collect:"XPlat Code Coverage;Format=opencover"

echo "==> Backend: dotnet-sonarscanner end"
dotnet-sonarscanner end /d:sonar.token="$SONAR_TOKEN"

echo "==> Frontend: tests with lcov coverage"
npm --prefix frontend run test -- --coverage

echo "Done. Frontend lcov report: frontend/coverage/lcov.info"
