locals {
  nonprod_apis = {
    dev     = "dev"
    staging = "staging"
  }
  nonprod_methods = ["GET", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD", "POST"]
  nonprod_operations = {
    for pair in setproduct(keys(local.nonprod_apis), local.nonprod_methods) :
    "${pair[0]}-${pair[1]}" => {
      environment = pair[0]
      method      = pair[1]
    }
  }
}

resource "azurerm_api_management_api" "nonprod" {
  for_each              = local.nonprod_apis
  name                  = "devops-${each.key}"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "DevOps ${each.key}"
  path                  = each.value
  protocols             = ["https"]
  service_url           = "http://127.0.0.1"
  subscription_required = false

  lifecycle {
    ignore_changes = [service_url]
  }
}

resource "azurerm_api_management_api_operation" "nonprod" {
  for_each            = local.nonprod_operations
  operation_id        = "method-${lower(each.value.method)}"
  api_name            = azurerm_api_management_api.nonprod[each.value.environment].name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "${each.value.method} DevOps"
  method              = each.value.method
  url_template        = "/DevOps"
}

resource "azurerm_api_management_api_operation_policy" "nonprod_post" {
  for_each            = local.nonprod_apis
  api_name            = azurerm_api_management_api.nonprod[each.key].name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  operation_id        = azurerm_api_management_api_operation.nonprod["${each.key}-POST"].operation_id
  xml_content         = file("${path.module}/policies/post.xml")
}
