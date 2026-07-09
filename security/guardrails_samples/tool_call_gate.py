"""
SAMPLE CODE -- not wired into any service. See README.md in this directory.

ASI02 (Tool Misuse) + ASI03 (Identity & Privilege Abuse) runtime guard.
Python mirror of src/backend/sample-service/.../agent/ToolCallGate.java: an
allowlist of tool names, per-tool argument/boundary validation, and a
short-lived credential scoped to one tool name so a hijacked agent can't
reuse it to call something else.
"""
from __future__ import annotations

import os
import time
from dataclasses import dataclass
from typing import Callable, Optional


@dataclass
class ScopedCredential:
    token: str
    tool_name: str
    expires_at: float

    def is_valid_for(self, tool_name: str) -> bool:
        return self.tool_name == tool_name and time.time() < self.expires_at


@dataclass
class ToolPolicy:
    allowed_kwargs: set[str]
    # args -> None if allowed, else a reason string to deny.
    validator: Callable[[dict], Optional[str]]
    executor: Callable[[dict], object]


class ToolCallDenied(Exception):
    pass


class ToolCallGate:
    def __init__(self):
        self._policies: dict[str, ToolPolicy] = {}

    def register(self, tool_name: str, policy: ToolPolicy) -> None:
        self._policies[tool_name] = policy

    def mint_credential(self, tool_name: str, ttl_seconds: float = 30.0) -> ScopedCredential:
        return ScopedCredential(
            token=os.urandom(16).hex(), tool_name=tool_name, expires_at=time.time() + ttl_seconds
        )

    def call(self, tool_name: str, credential: ScopedCredential, **kwargs):
        policy = self._policies.get(tool_name)
        if policy is None:
            raise ToolCallDenied(f"unknown tool: {tool_name}")
        if not credential.is_valid_for(tool_name):
            raise ToolCallDenied(f"credential invalid or expired for tool: {tool_name}")

        unexpected = set(kwargs) - policy.allowed_kwargs
        if unexpected:
            raise ToolCallDenied(f"unexpected arguments for {tool_name}: {unexpected}")

        deny_reason = policy.validator(kwargs)
        if deny_reason is not None:
            raise ToolCallDenied(f"boundary check failed for {tool_name}: {deny_reason}")

        return policy.executor(kwargs)


if __name__ == "__main__":
    from pathlib import Path

    def validate_write_file(kwargs: dict) -> Optional[str]:
        if Path(kwargs["relative_path"]).is_absolute():
            return f"relative_path must not be absolute: {kwargs['relative_path']}"
        allowed_root = Path(kwargs["allowed_root"]).resolve()
        target = (allowed_root / kwargs["relative_path"]).resolve()
        if not target.is_relative_to(allowed_root):
            return f"path escapes allowed root: {target}"
        if target.suffix.lower() not in {".txt", ".csv", ".json"}:
            return f"extension not allowed: {target.suffix}"
        if len(kwargs.get("content", "")) > 1_000_000:
            return "content exceeds size cap (1MB)"
        return None

    def execute_write_file(kwargs: dict) -> str:
        target = Path(kwargs["allowed_root"]).resolve() / kwargs["relative_path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(kwargs["content"])
        return str(target)

    gate = ToolCallGate()
    gate.register(
        "write_file",
        ToolPolicy(
            allowed_kwargs={"allowed_root", "relative_path", "content"},
            validator=validate_write_file,
            executor=execute_write_file,
        ),
    )

    cred = gate.mint_credential("write_file")

    path = gate.call(
        "write_file",
        cred,
        allowed_root="./sandbox_output",
        relative_path="report.txt",
        content="quarterly summary",
    )
    print(f"[ALLOW] wrote {path}")

    try:
        gate.call(
            "write_file",
            cred,
            allowed_root="./sandbox_output",
            relative_path="../../etc/passwd",
            content="pwned",
        )
    except ToolCallDenied as e:
        print(f"[BLOCK] {e}")

    try:
        gate.call("delete_file", cred, path="report.txt")
    except ToolCallDenied as e:
        print(f"[BLOCK] {e}")
