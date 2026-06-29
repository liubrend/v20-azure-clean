# Set the non-secret values as GitHub repo Variables so the deploy workflows resolve.

output "acr_login_server" {
  description = "ACR login server → GitHub var ACR_LOGIN_SERVER."
  value       = azurerm_container_registry.main.login_server
}

output "resource_group" {
  description = "Resource group name → GitHub var AZURE_RESOURCE_GROUP."
  value       = azurerm_resource_group.main.name
}

output "deploy_client_id" {
  description = "Deploy managed-identity client id → GitHub var AZURE_CLIENT_ID (for azure/login)."
  value       = azurerm_user_assigned_identity.deploy.client_id
}

output "api_gateway_app_name" {
  description = "api-gateway Container App name → GitHub var GATEWAY_APP_NAME."
  value       = azurerm_container_app.api_gateway.name
}

output "sample_service_app_name" {
  description = "sample-service Container App name → GitHub var SAMPLE_SERVICE_APP_NAME."
  value       = azurerm_container_app.sample_service.name
}

output "api_gateway_fqdn" {
  description = "Public hostname of the api-gateway."
  value       = azurerm_container_app.api_gateway.ingress[0].fqdn
}

output "static_web_app_host" {
  description = "Frontend hostname (Static Web App)."
  value       = azurerm_static_web_app.frontend.default_host_name
}

output "sql_server_fqdn" {
  description = "Azure SQL server FQDN."
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}
