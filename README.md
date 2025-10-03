ExiledProjectCMS — Main API (C#) skeleton

What’s included

- ASP.NET Core 8 minimal API in src\MainApi
- GML integrations implemented:
    - POST /api/v1/integrations/auth/signin — custom auth endpoint (required by GML)
    - GET /api/news — news list (limit, offset) for GML news import
- Health check: GET /health
- In-memory repositories for Users and News with seed data
- PowerShell script to check endpoints: tests\check_api.ps1

How to run

1) Open src\MainApi in Rider/VS or run: dotnet run --project src\MainApi\MainApi.csproj
2) By default Swagger UI is available in Development. Endpoints:
    - POST /api/v1/integrations/auth/signin
    - GET /api/news
    - GET /health

Seeded data

- Users:
    - admin / admin123 — OK
    - tester / test123 — 2FA required (returns 401 with message)
    - banned / banned123 — banned (returns 403)
- News: 3 demo items

Verify API via script

- PowerShell (Windows): ./tests/check_api.ps1 -BaseUrl http://localhost:5190
- Bash (Linux/macOS): ./tests/check_api.sh http://localhost:5190
  By default the base URL is http://localhost:5190; you can override it by passing the argument or via BASE_URL env var.

Notes and next steps

- DB: currently in-memory. Next: add EF Core + MySQL (Pomelo) and migration/seeding.
- 2FA: currently prompts with 401 message per GML docs. Next: extend flow to accept and validate TOTP.
- Auth tokens (JWT/refresh): to be added; a short doc will be written on protected endpoints once implemented.
- Docker Compose: add later (API + Redis, Prometheus exporters, etc.).
- Discord integration: per your note, will be implemented separately in JS later.
