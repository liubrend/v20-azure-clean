# Azure Static Web App hosts the Angular bundle (replaces Firebase Hosting). The
# deploy-frontend workflow pushes the built bundle here with a deployment token.
resource "azurerm_static_web_app" "frontend" {
  name                = "${var.name_prefix}-swa"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_tier            = "Free"
  sku_size            = "Free"
}
