## Code Conventions

### General
- Frontend talks to backend only through the typed API client in `src/backend/api/`.
- No business logic in route handlers — routers call service functions only.
- No raw SQL unless the ORM cannot express the query; document the reason.

### TypeScript
- `strict: true` always on.
- Prefer `interface` over `type` for object shapes.
- API response types in `src/types/` must stay in sync with backend Pydantic schemas.

### Python
- Pydantic v2 for all request/response schemas.
- SQLAlchemy models in `models/`; Pydantic schemas in `schemas/` — never mix them.
- All timestamps stored as UTC; convert to local only at the API response boundary if needed.
- All DB mutations go through the service layer, not directly from routers.

### Database
- Every schema change requires an Alembic migration — never modify tables by hand.
- Plural snake_case table names (e.g. `users`, `audit_events`).
- Every table has `id` (UUID or serial), `created_at`, `updated_at`.

## Testing Standards

- Unit tests: no DB or network — mock the service layer and ingestion calls.
- Integration tests: use a test Postgres (testcontainers); reset per test via transactions.
- Frontend: test component behavior, not implementation details.

---