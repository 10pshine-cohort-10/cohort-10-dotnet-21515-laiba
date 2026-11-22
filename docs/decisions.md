# Decisions Log

## ADR-001: Technology stack

**Status**: Accepted

**Context**: Need a stack for a college/internship task management assignment that is reviewed by CodeRabbit and a human supervisor, so conventional, well-documented technology choices matter more than novelty.

**Decision**: ASP.NET Core Web API + Entity Framework Core + SQL Server on the backend, React (Vite + TypeScript) on the frontend, Serilog for logging, xUnit for backend tests, SonarQube for static analysis and coverage.

**Reasons**:
- ASP.NET Core + EF Core + SQL Server is the standard, well-documented .NET combination for a relational CRUD app and matches the assignment's .NET focus.
- React + Vite + TypeScript gives a fast dev loop and type safety on the frontend with a mainstream, widely-supported toolchain.
- Serilog gives structured logging that's easy to query and extend with sinks later.
- xUnit is the de facto standard test framework for .NET and integrates cleanly with coverlet/SonarQube.
- SonarQube gives both the student and the supervisor an objective code-quality signal expected in professional workflows.

## ADR-002: Layered backend architecture

**Status**: Accepted

**Decision**: Four backend projects - Domain, Application, Infrastructure, Api - with dependencies flowing inward (Api/Infrastructure -> Application -> Domain).

**Reasons**: Keeps business rules (Domain/Application) independent of persistence and transport details, so EF Core or the Web API framework can change without touching business logic, and makes unit testing the core logic straightforward.

## ADR-003: Frontend pinned to TypeScript 5.9.3, not the scaffolded 7.0.2

**Status**: Accepted

**Context**: `npm create vite@latest -- --template react-ts` scaffolded TypeScript `~7.0.2` by default. Installing the approved ESLint toolchain (`typescript-eslint`) against it failed with an `ERESOLVE` dependency conflict.

**Decision**: Pin `typescript` to `5.9.3` (latest stable 5.x) in `frontend/package.json` instead of the scaffolded 7.x.

**Reasons**: `typescript-eslint@8.73.0` (the latest available) declares a peer dependency of `typescript >=4.8.4 <6.1.0` - it does not yet support the TypeScript 7 line. 5.9.3 is the latest version that satisfies that range and is fully supported by the rest of the approved frontend tooling (ESLint, Vitest, Testing Library). Revisit this pin once `typescript-eslint` adds TypeScript 7 support.
