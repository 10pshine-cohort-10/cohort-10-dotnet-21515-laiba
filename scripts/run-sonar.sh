#!/usr/bin/env bash
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
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

backend_available=0
[ -f "backend/TaskManagement.sln" ] && backend_available=1

frontend_available=0
[ -f "frontend/package.json" ] && frontend_available=1

PROJECT_KEY="cohort-10-dotnet-21515-laiba"

ran_steps=()
skipped_steps=()

skip_step() {
  local name="$1" reason="$2"
  echo "SKIPPED: $name - $reason"
  skipped_steps+=("$name")
}

find_sonar_scanner() {
  local name
  for name in sonar-scanner sonar-scanner.bat sonar-scanner.cmd; do
    if command -v "$name" >/dev/null 2>&1; then
      echo "$name"
      return 0
    fi
  done
  return 1
}

if [ "$backend_available" -eq 0 ] && [ "$frontend_available" -eq 0 ]; then
  skip_step "dotnet-sonarscanner begin" "backend/TaskManagement.sln and frontend/package.json not found"
  skip_step "dotnet build" "backend/TaskManagement.sln not found"
  skip_step "dotnet test" "backend/TaskManagement.sln not found"
  skip_step "npm run test -- --coverage" "frontend/package.json not found"
  skip_step "dotnet-sonarscanner end" "backend/TaskManagement.sln and frontend/package.json not found"

elif [ "$backend_available" -eq 1 ]; then
  # Backend-only or combined checkout: unchanged begin -> build -> test -> end
  # sequence. dotnet-sonarscanner always wraps a real dotnet build here.
  : "${SONAR_TOKEN:?SONAR_TOKEN env var must be set}"
  SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"

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

  echo "==> Backend: build"
  dotnet build backend/TaskManagement.sln
  ran_steps+=("dotnet build")

  echo "==> Backend: test with coverage"
  dotnet test backend/TaskManagement.sln --collect:"XPlat Code Coverage;Format=opencover"
  ran_steps+=("dotnet test")

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

else
  # Frontend-only checkout: no .NET build exists, so dotnet-sonarscanner
  # begin/end must NOT run (it only wraps a real dotnet build/test pass).
  skip_step "dotnet-sonarscanner begin" "backend/TaskManagement.sln not found - dotnet-sonarscanner cannot run without a .NET build"
  skip_step "dotnet build" "backend/TaskManagement.sln not found"
  skip_step "dotnet test" "backend/TaskManagement.sln not found"
  skip_step "dotnet-sonarscanner end" "backend/TaskManagement.sln not found - dotnet-sonarscanner cannot run without a .NET build"

  if scanner_cli="$(find_sonar_scanner)"; then
    : "${SONAR_TOKEN:?SONAR_TOKEN env var must be set}"
    SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"

    echo "==> Frontend: tests with lcov coverage"
    npm --prefix frontend run test -- --coverage
    ran_steps+=("npm run test -- --coverage")

    echo "==> Frontend: standalone $scanner_cli analysis"
    # Reusing the same project key/exclusions/token/host settings as the
    # dotnet-sonarscanner begin call above, as -D args (no properties file -
    # see the sonarqube skill/README for why).
    "$scanner_cli" \
      -Dsonar.projectKey="$PROJECT_KEY" \
      -Dsonar.sources="frontend/src" \
      -Dsonar.host.url="$SONAR_HOST_URL" \
      -Dsonar.token="$SONAR_TOKEN" \
      -Dsonar.exclusions="**/bin/**,**/obj/**,**/Migrations/**,**/node_modules/**,**/dist/**,**/*.g.cs,**/*.g.i.cs" \
      -Dsonar.coverage.exclusions="**/Migrations/**,**/Program.cs,frontend/src/**/*.test.*,frontend/src/**/*.spec.*" \
      -Dsonar.javascript.lcov.reportPaths="frontend/coverage/lcov.info" \
      -Dsonar.typescript.lcov.reportPaths="frontend/coverage/lcov.info"
    ran_steps+=("$scanner_cli")
  else
    skip_step "npm run test -- --coverage" "no SonarQube scanner available for a frontend-only checkout (see below)"
    skip_step "sonar-scanner" "standalone Sonar Scanner CLI not found on PATH (checked: sonar-scanner, sonar-scanner.bat, sonar-scanner.cmd) - dotnet-sonarscanner cannot analyze a frontend-only checkout without a .NET build. Install the Sonar Scanner CLI to enable analysis here, or add a backend checkout."
  fi
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
  echo "WARNING: no SonarQube analysis ran - see the SKIPPED lines above for why."
  exit 1
fi

echo ""
echo "Done."
