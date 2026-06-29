# Azure Container Apps: the managed runtime for the two microservices (replaces GKE
# Autopilot + the raw k8s manifests). The gateway is internet-facing; sample-service
# is internal-only and reachable from the gateway over the environment's private network.

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.name_prefix}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.name_prefix}-cae"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# --- sample-service (internal) ----------------------------------------------------
resource "azurerm_container_app" "sample_service" {
  name                         = "${var.name_prefix}-sample-service"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.runtime.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.runtime.id
  }

  # Connection strings come from Key Vault, surfaced as secret-backed env vars.
  secret {
    name                = "database-url"
    key_vault_secret_id = azurerm_key_vault_secret.database_url.id
    identity            = azurerm_user_assigned_identity.runtime.id
  }
  secret {
    name                = "blob-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.blob_connection_string.id
    identity            = azurerm_user_assigned_identity.runtime.id
  }

  ingress {
    external_enabled = false
    target_port      = 8081
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "sample-service"
      image  = var.sample_service_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PORT"
        value = "8081"
      }
      env {
        name  = "LIQUIBASE_ENABLED"
        value = "true"
      }
      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
      env {
        name        = "BLOB_CONNECTION_STRING"
        secret_name = "blob-connection-string"
      }
      env {
        name  = "BLOB_CONTAINER"
        value = var.blob_container
      }
    }
  }
}

# --- api-gateway (external) -------------------------------------------------------
resource "azurerm_container_app" "api_gateway" {
  name                         = "${var.name_prefix}-api-gateway"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.runtime.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.runtime.id
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "api-gateway"
      image  = var.gateway_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "PORT"
        value = "8080"
      }
      # Internal FQDN of the sample-service ingress.
      env {
        name  = "SAMPLE_SERVICE_URI"
        value = "https://${azurerm_container_app.sample_service.ingress[0].fqdn}"
      }
      env {
        name  = "FRONTEND_ORIGIN"
        value = "https://${azurerm_static_web_app.frontend.default_host_name}"
      }
    }
  }
}
