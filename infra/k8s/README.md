# Kubernetes manifests — v19-claudeTeamCCEY backend

Deployed to GKE Autopilot. Manifests use `${VAR}` placeholders rendered by the
backend deploy workflow with `envsubst` before `kubectl apply`.

| File | What |
|---|---|
| `serviceaccount.yaml` | pod identity, annotated for GKE Workload Identity (`${RUNTIME_SA_EMAIL}`) |
| `deployment.yaml` | backend + Cloud SQL Auth Proxy native sidecar; `DATABASE_URL` from the `app-db` Secret |
| `service.yaml` | internal ClusterIP, wired to the BackendConfig health check |
| `backendconfig.yaml` | GCE LB health check on `/health` (GKE CRD) |
| `ingress.yaml` + `managedcertificate.yaml` | HTTPS at `${API_HOST}` (managed cert) |
| `migrate-job.yaml` | one-shot `alembic upgrade head` before each rollout |

## Placeholders (substituted at deploy)

`${BACKEND_IMAGE}`, `${RUNTIME_SA_EMAIL}`, `${CLOUDSQL_INSTANCE}`, `${API_HOST}`, `${FRONTEND_ORIGIN}`, `${IMAGE_TAG}`.

## The DATABASE_URL secret

Never in git. The deploy workflow reads it from Secret Manager and syncs a k8s Secret:

```bash
DB_URL="$(gcloud secrets versions access latest --secret=app-database-url)"
kubectl create secret generic app-db \
  --from-literal=DATABASE_URL="$DB_URL" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## One-time exposure setup (bootstrap)

- Reserve a **global static IP** named `app-backend-ip`
  (`gcloud compute addresses create app-backend-ip --global`).
- Point a **DNS A record** for `${API_HOST}` at that IP.
- The managed certificate provisions automatically once DNS resolves. Because the
  SPA is HTTPS (Firebase Hosting), the API must be HTTPS — hence the managed cert,
  not a plain LoadBalancer.

## Local validation

```bash
# Same vars the CI L1-k8s-manifests job uses; renders placeholders, then schema-checks.
export BACKEND_IMAGE=img RUNTIME_SA_EMAIL=sa@example.iam.gserviceaccount.com \
  CLOUDSQL_INSTANCE=proj:reg:inst API_HOST=api.example.com IMAGE_TAG=ci
for f in serviceaccount deployment service ingress migrate-job; do
  envsubst < $f.yaml | kubeconform -strict -summary - ; done
# managedcertificate.yaml and backendconfig.yaml are GKE CRDs — validated at apply
# time on the cluster, not by kubeconform here.
```
