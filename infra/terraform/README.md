# Terraform — v19-claudeTeamCCEY infrastructure

Provisions the GCP runtime. This root module is the **foundation**: networking,
Artifact Registry, Cloud SQL, Secret Manager, GKE Autopilot. **Auth** (service
accounts, IAM, Workload Identity Federation) lives in its own files (`auth_*.tf`,
`wif.tf`, `service_accounts.tf`, `iam.tf`) so credential changes stay isolated.

## Use

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # set project_id, region
terraform init
terraform plan
terraform apply
```

## State

This module defaults to **local** state. For real use, configure a remote GCS
backend (a versioned, access-controlled bucket) — the state holds the generated DB
password. Do not commit `terraform.tfstate` (git-ignored).

## Auth / Workload Identity Federation (keyless CI)

`wif.tf`, `service_accounts.tf`, `iam.tf` set up GitHub Actions → GCP without any
stored key: GitHub's OIDC token is exchanged for short-lived credentials that
impersonate the **deploy** service account, restricted to this repository. The
backend pod runs as the **runtime** SA via GKE Workload Identity. No key is ever
created.

**One-time bootstrap (you, with your own credentials — runs once):**

```bash
gcloud auth login
gcloud config set project <PROJECT_ID>
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # set project_id, region;
                                                # github_repository defaults to liubrend/v19-claudeTeamCCEY
terraform init && terraform apply               # creates the WIF pool/provider, SAs, IAM
```

> `github_repository` and `github_ref` (default `refs/heads/main`) control who may
> assume the deploy identity — override them in `terraform.tfvars` if the repo/branch
> differs.

Then set these **GitHub repository variables** (Settings → Secrets and variables →
Actions → Variables) from the Terraform outputs — all non-secret:

| GitHub variable | Source |
|---|---|
| `WIF_PROVIDER` | `terraform output -raw wif_provider` |
| `DEPLOY_SA_EMAIL` | `terraform output -raw deploy_service_account_email` |
| `GCP_PROJECT_ID`, `GCP_REGION` | your values |
| `GCP_AR_REPO` | `terraform output -raw artifact_registry_repo` |
| `GKE_CLUSTER` | `terraform output -raw gke_cluster_name` |
| `CLOUDSQL_INSTANCE` | `terraform output -raw cloudsql_connection_name` |
| `RUNTIME_SA_EMAIL` | `terraform output -raw runtime_service_account_email` |
| `API_HOST` | your backend DNS host (e.g. `api.example.com`), pointed at the Ingress static IP |
| `FIREBASE_PROJECT_ID` | your Firebase project id (the frontend deploy target) |

No GitHub **secrets** are needed — WIF is keyless and the DB password stays in
Secret Manager.

## Notes

- The DB password is generated (`random_password`) and written to Secret Manager as
  `DATABASE_URL`; it is never placed in git or logs.
- `deletion_protection` guards Cloud SQL and the cluster; set it `false` only to tear
  a throwaway project down.
