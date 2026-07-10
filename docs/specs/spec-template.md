# spec-NNN — <Feature name>

## Summary
<What this feature does, in one or two sentences, in domain language (CONTEXT.md).>

## Motivation
<Why we are building it now; which PRD goal/journey it serves.>

## Scope
- In: <what this spec covers>
- Out: <what it explicitly does not>

## Behavior

Every scenario below becomes a test (L2). Use Given/When/Then. Each scenario has
a stable id (`S1`, `S2`, …); its test(s) **must reference** `spec-NNN:S<n>` in the
test name/title or a comment — e.g. `@DisplayName("spec-003:S2 rejects a market
order")` — so the L2 spec-traceability gate can confirm coverage and catch a spec
change that leaves a scenario untested.

### S1 — <scenario name>
- **Given** <starting state>
- **When** <action>
- **Then** <observable outcome>

### S2 — <scenario name>
- **Given** …
- **When** …
- **Then** …

## Acceptance criteria
- [ ] <criterion>
- [ ] All scenarios above have passing tests.

## Open questions
<Anything still undecided. Resolve before building.>
