# task-NNN — <Unit of work title>

- **Source spec:** `docs/specs/spec-NNN.md` (<scenario id(s), e.g. S1, S2>)
- **Source ADR:** `docs/adr/NNNN-<slug>.md` (if this task follows from a decision, else "n/a")
- **Status:** todo | in-progress | blocked | done

## Goal
<One or two sentences: the single, unit-sized piece of behavior this task adds
or changes. Small enough for one PR — if it needs "and" to describe, split it.>

## Context for the implementer
<What the coding agent needs to know before touching code: relevant existing
modules/files, data shapes, invariants from AGENTS.md/CLAUDE.md that apply here,
and any decisions already made in the source spec/ADR. Do not restate the whole
spec — link to it and pull out only what constrains this unit.>

## Touch points
- **Add/modify:** `<path/to/file>` — <what changes here>
- **Add/modify:** `<path/to/file>` — <what changes here>
- **Tests:** `<path/to/test file>` — <what it must prove>

## Steps
1. <First implementation step, in the order an implementer should do it>
2. <Next step>
3. <Wire up tests / verify against the spec scenario(s) above>

## Acceptance criteria
- [ ] <Observable behavior that proves the task is done — trace back to the spec scenario>
- [ ] Tests for the touch points above pass (`L2`).
- [ ] No changes outside the touch points listed (if scope grew, split a new task).

## Out of scope
<What this task deliberately does not do, so the implementer doesn't over-build.>

## Open questions
<Anything blocking implementation that needs a human or spec/ADR answer first.>
