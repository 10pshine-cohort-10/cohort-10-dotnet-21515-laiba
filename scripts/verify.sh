#!/usr/bin/env bash
# Runs the full verification suite, stopping at the first failure.
# Works on a partial checkout: a step whose project (backend/ or frontend/)
# doesn't exist yet at this revision is skipped rather than failing.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

DOTNET="${DOTNET_EXE:-dotnet}"

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

if [ "$backend_available" -eq 1 ]; then
  echo "==> dotnet build"
  "$DOTNET" build backend/TaskManagement.sln
  ran_steps+=("dotnet build")

  echo "==> dotnet test"
  "$DOTNET" test backend/TaskManagement.sln
  ran_steps+=("dotnet test")
else
  skip_step "dotnet build" "backend/TaskManagement.sln not found"
  skip_step "dotnet test" "backend/TaskManagement.sln not found"
fi

if [ "$frontend_available" -eq 1 ]; then
  echo "==> npm run lint"
  npm --prefix frontend run lint
  ran_steps+=("npm run lint")

  echo "==> npm run test"
  npm --prefix frontend run test
  ran_steps+=("npm run test")

  echo "==> npm run build"
  npm --prefix frontend run build
  ran_steps+=("npm run build")
else
  skip_step "npm run lint" "frontend/package.json not found"
  skip_step "npm run test" "frontend/package.json not found"
  skip_step "npm run build" "frontend/package.json not found"
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
echo "All checks passed."
