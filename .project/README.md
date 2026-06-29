# `.project/`

Machine-readable project metadata that agents rely on. Keep consistent with `/CONTEXT.md`, `docs/adr/`, and `docs/product/`.

| File | Purpose |
|---|---|
| `config.yaml` | Project name, current phase, team metadata |
| `stack.yaml` | Finalized technical stack and verified dev commands (the tech spec agents read) |
| `plan.md` | Current build order and step status |

## Related docs (outside `.project/`)

- `/CONTEXT.md` — canonical domain glossary
- `docs/product/prd.md` — product requirements
- `docs/product/architecture.md` — system architecture and data flow
- `docs/adr/` — Architecture Decision Records (`0001-*.md` …)
- `docs/context/engineer-standard.md` — code conventions