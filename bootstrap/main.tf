data "azurerm_client_config" "current" {}

locals {
  suffix = substr(sha1(var.subscription_id), 0, 6)
  tags   = { app = "crux", managed_by = "terraform", stack = "bootstrap" }

  # Roles CI may hand out inside the env resource groups — nothing else.
  delegable_roles = [
    "4633458b-17de-408a-b874-0445c86b69e6", # Key Vault Secrets User
    "ba92f5b4-2d11-453d-a403-e96b0029c9fe", # Storage Blob Data Contributor
  ]
  delegable_guids = join(", ", local.delegable_roles)
}

# ---------------------------------------------------------------------------
# Terraform state
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-crux-tfstate"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "stcruxtfstate${local.suffix}"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = local.tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Environment resource groups
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "env" {
  for_each = toset(var.environments)

  name     = "rg-crux-${each.key}"
  location = var.location
  tags     = merge(local.tags, { env = each.key })
}

# ---------------------------------------------------------------------------
# GitHub Actions identity (OIDC — no client secret)
# ---------------------------------------------------------------------------

resource "azuread_application" "github" {
  display_name = "crux-infra-github"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "github" {
  client_id = azuread_application.github.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each = {
    pull-request = "repo:${var.github_repository}:pull_request"
    main         = "repo:${var.github_repository}:ref:refs/heads/main"
  }

  application_id = azuread_application.github.id
  display_name   = "github-${each.key}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value
}

resource "azurerm_role_assignment" "github_contributor" {
  for_each = azurerm_resource_group.env

  scope                = each.value.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github.object_id
}

resource "azurerm_role_assignment" "github_rbac_admin" {
  for_each = azurerm_resource_group.env

  scope                = each.value.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azuread_service_principal.github.object_id
  condition_version    = "2.0"
  condition            = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.delegable_guids}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.delegable_guids}}
     )
    )
  EOT
}

# Terraform writes the generated DATABASE_URL into the env's Key Vault.
resource "azurerm_role_assignment" "github_kv_secrets" {
  for_each = azurerm_resource_group.env

  scope                = each.value.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azuread_service_principal.github.object_id
}

resource "azurerm_role_assignment" "github_tfstate" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github.object_id
}

# ---------------------------------------------------------------------------
# Admins (Entra group): state access + setting secrets by hand
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "admins_tfstate" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.admin_group_object_id
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "admins_kv_secrets" {
  for_each = azurerm_resource_group.env

  scope                = each.value.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.admin_group_object_id
  principal_type       = "Group"
}

# ---------------------------------------------------------------------------
# Budget
# ---------------------------------------------------------------------------

resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "crux-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    operator       = "GreaterThan"
    threshold      = 80
    threshold_type = "Actual"
    contact_emails = var.budget_contact_emails
  }

  notification {
    operator       = "GreaterThan"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = var.budget_contact_emails
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
