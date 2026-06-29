## Code Conventions

### General
- Frontend talks to backend only through the api-gateway (`/api/**`), never directly to a domain service.
- No business logic in controllers — controllers call `@Service` methods only.
- No raw SQL unless JPA cannot express the query; document the reason.

### TypeScript (frontend)
- `strict: true` always on.
- Prefer `interface` over `type` for object shapes.
- Frontend response types must stay in sync with the backend REST DTOs.

### Java (backend)
- Spring Boot 3.4 on Java 21; constructor injection only (no field `@Autowired`).
- DTOs (records) at the web boundary; never expose JPA entities directly — map via `from(...)`.
- All timestamps stored as UTC (`Instant`); convert to local only at the API response boundary if needed.
- All DB mutations go through the `@Service` layer, not directly from controllers.

### Database
- Every schema change requires a Liquibase changeSet — never modify tables by hand.
- Plural snake_case table names (e.g. `items`, `audit_events`).
- Every table has `id`, `created_at`.

## Testing Standards

- Unit tests: no DB or network — mock the repository/blob layer with Mockito; controller slices use `@WebMvcTest`.
- Integration tests: use a test SQL Server (Testcontainers) in the `integrationTest` source set; Liquibase applies the schema.
- Frontend: test component behavior, not implementation details (Karma + Jasmine).

---
