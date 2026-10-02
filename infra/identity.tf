locals {
  github_subject = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}:environment:%s"
}

resource "azuread_application" "github" {
  display_name = "github-devops-challenge"
}

resource "azuread_service_principal" "github" {
  client_id = azuread_application.github.client_id
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each       = toset(["dev", "staging", "prod"])
  application_id = azuread_application.github.id
  display_name   = "github-${each.value}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = format(local.github_subject, each.value)
}

resource "azurerm_role_assignment" "github_contributor" {
  scope                            = azurerm_resource_group.rg.id
  role_definition_name             = "Contributor"
  principal_id                     = azuread_service_principal.github.object_id
  skip_service_principal_aad_check = true
}
