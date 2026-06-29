# Azure SQL Database — the system of record (replaces Cloud SQL for PostgreSQL).
# The admin password is generated into Terraform state and stored in Key Vault;
# never hardcoded, never in git (CLAUDE.md invariant).
resource "random_password" "sql_admin" {
  length  = 32
  special = true
}

resource "azurerm_mssql_server" "main" {
  name                         = "${var.name_prefix}-sql"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"
}

resource "azurerm_mssql_database" "app" {
  name      = var.db_name
  server_id = azurerm_mssql_server.main.id
  sku_name  = var.sql_sku
  collation = "SQL_Latin1_General_CP1_CI_AS"
}

# Allow Azure-hosted services (Container Apps) to reach the server. The 0.0.0.0
# "rule" is the Azure convention for "allow Azure internal traffic only".
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
