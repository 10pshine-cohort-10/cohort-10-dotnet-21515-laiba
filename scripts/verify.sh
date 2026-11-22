#!/usr/bin/env bash
# Runs the full verification suite, stopping at the first failure.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

DOTNET="${DOTNET_EXE:-dotnet}"

echo "==> dotnet build"
"$DOTNET" build backend/TaskManagement.sln

echo "==> dotnet test"
"$DOTNET" test backend/TaskManagement.sln

echo "==> npm run lint"
npm --prefix frontend run lint

echo "==> npm run test"
npm --prefix frontend run test

echo "==> npm run build"
npm --prefix frontend run build

echo "All checks passed."
