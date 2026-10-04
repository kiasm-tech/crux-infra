terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "deployments" {
  description = "Deployment name (what apps send as the model) => model. No version = the model's default."
  type = map(object({
    model    = string
    version  = optional(string)
    sku      = optional(string, "GlobalStandard")
    capacity = optional(number, 50)
  }))
}

# AIServices: the OpenAI deployments and Speech behind one endpoint and one key.
resource "azurerm_cognitive_account" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "AIServices"
  sku_name                      = "S0"
  custom_subdomain_name         = var.name
  local_auth_enabled            = true
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_cognitive_deployment" "this" {
  for_each = var.deployments

  name                   = each.key
  cognitive_account_id   = azurerm_cognitive_account.this.id
  version_upgrade_option = "OnceNewDefaultVersionAvailable"

  model {
    format  = "OpenAI"
    name    = each.value.model
    version = each.value.version
  }

  sku {
    name     = each.value.sku
    capacity = each.value.capacity
  }
}

output "name" { value = azurerm_cognitive_account.this.name }
output "location" { value = azurerm_cognitive_account.this.location }
output "openai_base_url" { value = "https://${azurerm_cognitive_account.this.custom_subdomain_name}.openai.azure.com/openai/v1" }
output "deployments" { value = keys(azurerm_cognitive_deployment.this) }

output "primary_access_key" {
  value     = azurerm_cognitive_account.this.primary_access_key
  sensitive = true
}
