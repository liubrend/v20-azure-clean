# Identities.
#
# 1) runtime — a user-assigned managed identity the Container Apps run as. It pulls
#    images from ACR and reads connection strings from Key Vault. No secrets stored.
# 2) deploy — a user-assigned managed identity GitHub Actions assumes KEYLESSLY via an
#    OIDC federated credential (replaces GCP Workload Identity Federation). `azure/login`
#    presents the Actions OIDC token; Azure exchanges it for a short-lived token. Nothing
#    long-lived is stored in GitHub.

# --- runtime identity -------------------------------------------------------------
resource "azurerm_user_assigned_identity" "runtime" {
  name                = "${var.name_prefix}-runtime"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "runtime_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.runtime.principal_id
}

resource "azurerm_role_assignment" "runtime_kv_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.runtime.principal_id
}

# --- deploy identity (GitHub OIDC) ------------------------------------------------
resource "azurerm_user_assigned_identity" "deploy" {
  name                = "${var.name_prefix}-deploy"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Only this repo's main-branch Actions runs may assume the deploy identity.
resource "azurerm_federated_identity_credential" "github_main" {
  name                = "github-main"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.deploy.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repository}:ref:${var.github_ref}"
}

# Deploy identity permissions: push images, update Container Apps, deploy SWA.
resource "azurerm_role_assignment" "deploy_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}

resource "azurerm_role_assignment" "deploy_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}
