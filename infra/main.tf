terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "random" {}

provider "azuread" {
  tenant_id = var.tenant_id
}

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_service_versions" "eastus" {
  location = var.location
}

resource "terraform_data" "tenant_guard" {
  lifecycle {
    precondition {
      condition     = data.azurerm_client_config.current.tenant_id == var.tenant_id
      error_message = "The Azure CLI session is not in var.tenant_id."
    }
  }
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-devops-challenge"
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_registry" "acr" {
  name                = "acrdevops${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-devops-challenge"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "devops${random_string.suffix.result}"
  kubernetes_version  = data.azurerm_kubernetes_service_versions.eastus.latest_version
  sku_tier            = "Free"
  tags                = var.tags

  default_node_pool {
    name            = "system"
    node_count      = 2
    vm_size         = var.vm_size
    os_disk_size_gb = 64
    os_disk_type    = "Managed"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_api_management" "apim" {
  name                = "apim-devops-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = var.publisher_name
  publisher_email     = var.alert_email
  sku_name            = "Consumption_0"
  tags                = var.tags
}

resource "azurerm_api_management_named_value" "api_key" {
  name                = "api-key"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "api-key"
  secret              = true
  value               = var.api_key
}

resource "azurerm_api_management_named_value" "jwt_key" {
  name                = "jwt-signing-key"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "jwt-signing-key"
  secret              = true
  value               = base64encode(var.jwt_secret)
}

resource "azurerm_api_management_api" "devops" {
  name                  = "devops"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "DevOps"
  path                  = ""
  protocols             = ["https"]
  service_url           = "http://127.0.0.1"
  subscription_required = false

  lifecycle {
    ignore_changes = [service_url]
  }
}

resource "azurerm_api_management_api_operation" "post" {
  operation_id        = "post-devops"
  api_name            = azurerm_api_management_api.devops.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "POST DevOps"
  method              = "POST"
  url_template        = "/DevOps"
}

resource "azurerm_api_management_api_operation_policy" "post" {
  api_name            = azurerm_api_management_api.devops.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  operation_id        = azurerm_api_management_api_operation.post.operation_id
  xml_content         = file("${path.module}/policies/post.xml")
}

resource "azurerm_api_management_api_operation" "open" {
  for_each            = toset(["GET", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"])
  operation_id        = "method-${lower(each.value)}"
  api_name            = azurerm_api_management_api.devops.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "${each.value} DevOps"
  method              = each.value
  url_template        = "/DevOps"
}

resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "devops-challenge-30"
  subscription_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  amount          = 30
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-10-01T00:00:00Z"
    end_date   = "2027-09-30T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}
