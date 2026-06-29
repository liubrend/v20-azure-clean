## The workflow (non-negotiable)
1. **Plan** — write a spec in `docs/features/` *before* code. No spec, no build. (use `docs/features/spec-template.md` as the starting point; CLAUDE.md lists the full doc set.)
2. **Develop** — implement to the spec; keep diffs small and single-purpose.
3. **Test** — every spec scenario (Given/When/Then) becomes a test; all green before review.
4. **Review** — the `reviewer` subagent (L4) produces findings; high-severity escalates.
5. **Deploy** — a human approves and records the decision in `docs/audit/log.md`. Agents never self-approve.

## Test and validation
L1: Policy checks — security, compliance, architecture rules, automated
L2: Test proof — unit + integration, bound to the spec, automated
L3: Diff heuristics — file count, ownership, blast radius, automated
L4: AI review gate — model feedback tuned for risk, automated by agent: reviewer
L5: Human escalation — high-risk / low-confidence only, human only
**Must apply all L1-L4 automatically and leave L5 to human review**

