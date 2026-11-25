# cohort-10-dotnet-21515-laiba
Cohort 10 — .NET Fullstack (.NET+ReactJS) assignment for Laiba kanwal

## Overview

A web-based task management tool: register/login with roles (Admin, User), create/assign tasks with priority/category/due dates, and track progress on a dashboard. This repo is currently at **Phase 0 (scaffolding)** - structure and tooling only, no business logic yet. See [docs/decisions.md](docs/decisions.md) for why this stack was chosen.

## Tech Stack

- **Backend**: ASP.NET Core Web API (.NET 10), Entity Framework Core, SQL Server, Serilog, FluentValidation, xUnit + Moq + FluentAssertions
- **Frontend**: React + Vite + TypeScript (strict), Tailwind CSS, TanStack Query, axios, react-hook-form + zod, react-router-dom, recharts
- **Quality**: SonarQube (static analysis + coverage), CodeRabbit (automated PR review)
- **Infra**: Docker Compose (SQL Server), Git

## Project Structure

This is the target structure for the project; `backend/` and `frontend/` land in their own follow-up PRs and are not part of this revision yet (see [Roadmap](#roadmap)).

```
/
├── backend/            # ASP.NET Core solution (Domain/Application/Infrastructure/Api + tests) - planned, follow-up PR
├── frontend/           # React + Vite + TypeScript app - planned, follow-up PR
├── docs/               # architecture, API, database, decisions
├── scripts/            # verify + SonarQube scripts (Git Bash & PowerShell)
└── docker-compose.yml  # local SQL Server
```

See [docs/architecture.md](docs/architecture.md) for the layering details.

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [Node.js](https://nodejs.org/) 20+ and npm
- [Docker](https://www.docker.com/) (for the local SQL Server container)

## Getting Started

The steps below describe each part once its PR has landed (see [Roadmap](#roadmap)); they don't all apply at once on a fresh partial checkout.

### Backend _(planned - follow-up PR)_

```bash
cd backend
dotnet restore TaskManagement.sln
dotnet run --project src/TaskManagement.Api
```

The API starts with a `/health` endpoint and OpenAPI document at `/openapi/v1.json`.

### Frontend _(planned - follow-up PR)_

```bash
cd frontend
npm install
cp .env.example .env   # adjust VITE_API_BASE_URL if needed
npm run dev
```

### Database (Docker)

```bash
cp .env.example .env   # adjust SQL Server credentials if needed
docker compose up -d
```

## Running Tests

```bash
# Backend
cd backend
dotnet test TaskManagement.sln

# Frontend (from backend/, go up one level first)
cd ../frontend
npm run test
```

Or run everything at once, in order, stopping at the first failure (`dotnet build` -> `dotnet test` -> `npm run lint` -> `npm run test` -> `npm run build`) from the repo root. Steps are skipped automatically (with a `SKIPPED: ...` line and a summary at the end) when `backend/` or `frontend/` isn't present yet at the current revision.

```bash
# Git Bash
scripts/verify.sh
```
```powershell
# PowerShell
scripts/verify.ps1
```

## Code Quality (SonarQube)

Prerequisites: a reachable SonarQube/SonarCloud server, the `dotnet-sonarscanner` global tool installed, and a `SONAR_TOKEN` environment variable set (never hardcoded; optionally `SONAR_HOST_URL` if not `http://localhost:9000`).

```bash
# Git Bash
scripts/run-sonar.sh
```
```powershell
# PowerShell
scripts/run-sonar.ps1
```

This runs `dotnet-sonarscanner begin` -> backend build/test with coverage -> a frontend coverage run -> `dotnet-sonarscanner end`. As with `scripts/verify.*`, the backend and/or frontend steps are skipped automatically when that part of the repository isn't present yet at the current revision (and the whole run is skipped if neither is present). `dotnet-sonarscanner` does not read `sonar-project.properties`, so there isn't one - every setting (coverage report paths, analysis exclusions for migrations/generated files/`bin`/`obj`/`node_modules`/`dist`) is passed as an explicit `/d:` argument in the `begin` call inside `scripts/run-sonar.sh` / `scripts/run-sonar.ps1`. Coverage reports: backend coverlet `opencover` XML under `backend/tests/**/coverage.opencover.xml`, frontend Vitest `lcov` at `frontend/coverage/lcov.info`.

## Git Workflow

- Branches: `feature/<name>`, `fix/<name>`, `chore/<name>`
- Commits: [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): summary`), small and atomic - one logical change per commit
- Keep PRs small and focused; resolve all CodeRabbit/reviewer comments before merging
- Never push directly from automation

## Roadmap

- [x] Phase 0a - repo tooling, scripts, docs, conventions (this PR)
- [ ] Phase 0b - backend solution scaffolding - planned, follow-up PR
- [ ] Phase 0c - frontend app scaffolding - planned, follow-up PR
- [ ] Phase 1 - authentication & roles (register/login, Admin/User)
- [ ] Phase 2 - task CRUD (priority, categories, due dates, assignment)
- [ ] Phase 3 - logging & global exception handling
- [ ] Phase 4 - unit tests & SonarQube integration
- [ ] Phase 5 - frontend screens (dashboard, task list, task detail, new/edit task, profile)

## Screenshots

_Coming soon._
