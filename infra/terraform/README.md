# Terraform — v20-Azure-clean-teamsEnabled infrastructure

Provisions the Azure runtime. This root module is the **foundation**: resource group,
Container Registry (ACR), Container Apps environment + the two microservices, Azure SQL
Database, Storage account + Blob container, and Key Vault. **Auth** (the deploy/runtime
managed identities, role assignments, GitHub OIDC federated credential) lives in
`identity.tf` so credential changes stay isolated.

## Use

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # set subscription_id, location
terraform init
terraform plan
terraform apply
```

## State

This module defaults to **local** state. For real use, configure a remote `azurerm`
backend (a versioned, RBAC-restricted Storage container) — the state holds the
generated SQL admin password. Do not commit `terraform.tfstate` (git-ignored).

## Auth / GitHub OIDC (keyless CI)

`identity.tf` sets up GitHub Actions → Azure without any stored key: GitHub's OIDC
token is exchanged (via `azure/login`) for short-lived credentials that act as the
**deploy** user-assigned managed identity, restricted to this repository's `main` ref
through a federated identity credential. The Container Apps run as the **runtime**
managed identity (ACR pull + Key Vault secrets). No client secret is ever created.

**One-time bootstrap (you, with your own credentials — runs once):**

```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # set subscription_id, location;
                                                # github_repository defaults to liubrend/v20-Azure-clean-teamsEnabled
terraform init && terraform apply               # creates ACR, SQL, storage, Key Vault, identities, apps
```

> `github_repository` and `github_ref` (default `refs/heads/main`) control who may
> assume the deploy identity — override them in `terraform.tfvars` if the repo/branch
> differs.

Then set these **GitHub repository variables** (Settings → Secrets and variables →
Actions → Variables) from the Terraform outputs — all non-secret:

| GitHub variable | Source |
|---|---|
| `AZURE_CLIENT_ID` | `terraform output -raw deploy_client_id` |
| `AZURE_TENANT_ID` | your tenant id |
| `AZURE_SUBSCRIPTION_ID` | your subscription id |
| `AZURE_RESOURCE_GROUP` | `terraform output -raw resource_group` |
| `ACR_LOGIN_SERVER` | `terraform output -raw acr_login_server` |
| `GATEWAY_APP_NAME` | `terraform output -raw api_gateway_app_name` |
| `SAMPLE_SERVICE_APP_NAME` | `terraform output -raw sample_service_app_name` |
| `API_HOST` | `terraform output -raw api_gateway_fqdn` |

Plus one **GitHub secret** for the frontend deploy:

| GitHub secret | Source |
|---|---|
| `AZURE_STATIC_WEB_APPS_API_TOKEN` | Static Web App deployment token (Azure portal → SWA → Manage deployment token) |

The backend stays keyless (OIDC). The DB/Blob connection strings stay in Key Vault.

## Notes

- The SQL admin password is generated (`random_password`) and written to Key Vault as
  `database-url`; it is never placed in git or logs.
- The Container App `image` vars default to a placeholder; the `deploy-backend`
  workflow updates each app to the freshly built image tag.
