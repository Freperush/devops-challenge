output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "apim_name" {
  value = azurerm_api_management.apim.name
}

output "gateway_url" {
  value = azurerm_api_management.apim.gateway_url
}
