# Azure Container Registry — holds the api-gateway and sample-service images
# (replaces the GCP Artifact Registry repository).
resource "azurerm_container_registry" "main" {
  name                = "${var.name_prefix}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = false
}
