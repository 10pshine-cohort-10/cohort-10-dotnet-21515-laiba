#!/usr/bin/env bash
# Runs local SonarQube analysis for backend + frontend.
# Requires: dotnet-sonarscanner installed, SONAR_TOKEN set, a reachable Sonar server (SONAR_HOST_URL).
# Works on a partial checkout: a step whose project (backend/ or frontend/)
# doesn't exist yet at this revision is skipped rather than failing. If
# neither exists, the whole sonar run (including begin/end) is skipped.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

backend_available=0
[ -f "backend/TaskManagement.sln" ] && backend_available=1

frontend_available=0
[ -f "frontend/package.json" ] && frontend_available=1

ran_steps=()
skipped_steps=()

skip_step() {
  local name="$1" reason="$2"
  echo "SKIPPED: $name - $reason"
  skipped_steps+=("$name")
}

if [ "$backend_available" -eq 0 ] && [ "$frontend_available" -eq 0 ]; then
  skip_step "dotnet-sonarscanner begin" "backend/TaskManagement.sln and frontend/package.json not found"
  skip_step "dotnet build" "backend/TaskManagement.sln not found"
  skip_step "dotnet test" "backend/TaskManagement.sln not found"
  skip_step "npm run test -- --coverage" "frontend/package.json not found"
  skip_step "dotnet-sonarscanner end" "backend/TaskManagement.sln and frontend/package.json not found"
else
  # Only required once we know at least one side of the analysis will run.
  : "${SONAR_TOKEN:?SONAR_TOKEN env var must be set}"
  SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
  PROJECT_KEY="cohort-10-dotnet-21515-laiba"

  echo "==> Backend: dotnet-sonarscanner begin"
  # dotnet-sonarscanner does not read sonar-project.properties - every setting it
  # needs has to be passed as a /d: argument here.
  dotnet-sonarscanner begin \
    /k:"$PROJECT_KEY" \
    /d:sonar.host.url="$SONAR_HOST_URL" \
    /d:sonar.token="$SONAR_TOKEN" \
    /d:sonar.exclusions="**/bin/**,**/obj/**,**/Migrations/**,**/node_modules/**,**/dist/**,**/*.g.cs,**/*.g.i.cs" \
    /d:sonar.coverage.exclusions="**/Migrations/**,**/Program.cs,frontend/src/**/*.test.*,frontend/src/**/*.spec.*" \
    /d:sonar.cs.opencover.reportsPaths="backend/tests/**/coverage.opencover.xml" \
    /d:sonar.javascript.lcov.reportPaths="frontend/coverage/lcov.info" \
    /d:sonar.typescript.lcov.reportPaths="frontend/coverage/lcov.info"
  ran_steps+=("dotnet-sonarscanner begin")

  if [ "$backend_available" -eq 1 ]; then
    echo "==> Backend: build"
    dotnet build backend/TaskManagement.sln
    ran_steps+=("dotnet build")

    echo "==> Backend: test with coverage"
    dotnet test backend/TaskManagement.sln --collect:"XPlat Code Coverage;Format=opencover"
    ran_steps+=("dotnet test")
  else
    skip_step "dotnet build" "backend/TaskManagement.sln not found"
    skip_step "dotnet test" "backend/TaskManagement.sln not found"
  fi

  if [ "$frontend_available" -eq 1 ]; then
    echo "==> Frontend: tests with lcov coverage"
    npm --prefix frontend run test -- --coverage
    ran_steps+=("npm run test -- --coverage")
  else
    skip_step "npm run test -- --coverage" "frontend/package.json not found"
  fi

  echo "==> Backend: dotnet-sonarscanner end"
  dotnet-sonarscanner end /d:sonar.token="$SONAR_TOKEN"
  ran_steps+=("dotnet-sonarscanner end")
fi

echo ""
echo "==> Summary"
for s in "${ran_steps[@]:-}"; do
  [ -n "$s" ] && echo "  RAN:     $s"
done
for s in "${skipped_steps[@]:-}"; do
  [ -n "$s" ] && echo "  SKIPPED: $s"
done

if [ "${#ran_steps[@]}" -eq 0 ]; then
  echo ""
  echo "WARNING: no checks ran - backend/ and frontend/ are both missing at this revision."
  exit 1
fi

echo ""
echo "Done. Frontend lcov report: frontend/coverage/lcov.info"
