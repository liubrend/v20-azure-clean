# Key Vault holds the DB and Blob connection strings (replaces GCP Secret Manager).
# Container Apps reference these as secret-backed env vars at runtime.
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "${var.name_prefix}-kv"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
}

# JDBC connection string for the sample-service datasource.
resource "azurerm_key_vault_secret" "database_url" {
  name = "database-url"
  value = format(
    "jdbc:sqlserver://%s:1433;database=%s;encrypt=true;trustServerCertificate=false;user=%s;password=%s",
    azurerm_mssql_server.main.fully_qualified_domain_name,
    var.db_name,
    var.sql_admin_login,
    random_password.sql_admin.result,
  )
  key_vault_id = azurerm_key_vault.main.id
}

# Blob Storage connection string for the BlobStorageService.
resource "azurerm_key_vault_secret" "blob_connection_string" {
  name         = "blob-connection-string"
  value        = azurerm_storage_account.main.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id
}
