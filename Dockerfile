# v19-GCP-clean-teamsEnabled FastAPI backend image. Runs on GKE Autopilot behind the
# Cloud SQL Auth Proxy. Python 3.12 to match CI.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONPATH=/app/src

WORKDIR /app

# Deps first for layer caching.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Application + migrations (alembic.ini: script_location=src/data/migrations).
COPY src ./src
COPY alembic.ini ./

# Run unprivileged.
RUN useradd --uid 10001 --create-home app && chown -R app /app
USER app

EXPOSE 8080

# DATABASE_URL is injected at runtime (Secret Manager → k8s Secret); never baked in.
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8080"]
