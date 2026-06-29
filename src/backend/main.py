"""Minimal FastAPI application entrypoint.

Kept dependency-free (no DB) so the L2 test and image-import gates pass on a
fresh scaffold. Add routers, a service layer, and the `src/data` layer as the
project grows (see AGENTS.md and docs/context/engineer-standard.md).
"""

from __future__ import annotations

from fastapi import FastAPI

app = FastAPI(title="v19-GCP-clean-teamsEnabled", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe used by the GKE BackendConfig health check."""
    return {"status": "ok"}


@app.get("/")
def root() -> dict[str, str]:
    """Service identity at the root path."""
    return {"service": "v19-GCP-clean-teamsEnabled", "status": "ok"}
