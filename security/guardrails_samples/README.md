# Runtime guardrail samples (Python) -- reference only, not wired in

This directory is **sample code, not production code**. It is not imported by
any service, not run in CI, and not covered by `security/ai_sbom.json`.

The actual runtime guards for this repo's Java service are the real thing:
`src/backend/sample-service/src/main/java/com/v20azure/sample/agent/` (`IntentGuard`,
`MemoryIntegrityGuard`, `ToolCallGate`), with tests under the matching `src/test`
path. Those are what to extend when an agent is actually wired into
`sample-service`.

These Python versions exist for two reasons:
1. As a language-agnostic reference for the same three ASI guards, in case a
   future service in this repo is Python-based (e.g. a separate agent/RAG
   microservice) rather than an extension of the existing Java service.
2. As executable documentation -- each file has a `__main__` block that
   demonstrates allow/block behavior when run directly, which is faster to
   read than prose.

| File | ASI risk | Mirrors |
|---|---|---|
| `input_intent_check.py` | ASI01 Agent Goal Hijack | `IntentGuard.java` |
| `memory_integrity_check.py` | ASI06 Memory & Context Poisoning | `MemoryIntegrityGuard.java` |
| `tool_call_gate.py` | ASI02/ASI03 Tool Misuse / Privilege Abuse | `ToolCallGate.java` |

If you promote one of these from sample to production use, move it out of
`guardrails_samples/`, add it to `security/ai_sbom.json` as a tool definition,
and give it real tests under a `test_` path picked up by whatever Python test
runner that service uses -- none of that applies while it lives here.
