provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# Resource group holding the whole foundation.
resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-rg"
  location = var.location
}
