# ---------------------------------------------------------------------------
# Star Catch backend (kiasm-tech/star-catch): one image, an app per entrypoint
# ---------------------------------------------------------------------------

locals {
  star_catch = var.star_catch != null

  # Key Vault secrets each identity may read, one role assignment per secret:
  # the webhook secret stays with intake.
  star_catch_access = local.star_catch ? {
    intake = ["database-url", "github-webhook-secret", "ghcr-token"]
  } : {}

  star_catch_grants = {
    for grant in flatten([
      for app, secrets in local.star_catch_access : [for secret in secrets : { app = app, secret = secret }]
    ]) : "${grant.app}/${grant.secret}" => grant
  }

  star_catch_registry = local.star_catch ? {
    server          = "ghcr.io"
    username        = var.star_catch.registry_username
    password_secret = "ghcr-token"
  } : null
}

resource "azurerm_user_assigned_identity" "star_catch" {
  for_each = local.star_catch_access

  name                = "id-star-catch-${each.key}-${local.env}"
  resource_group_name = local.rg
  location            = var.location
  tags                = local.tags
}

# Scoped by id, not looked up: a data source would copy the values into state.
resource "azurerm_role_assignment" "star_catch_secrets" {
  for_each   = local.star_catch_grants
  depends_on = [azurerm_key_vault_secret.database_url, azurerm_key_vault_secret.ai_services_key]

  scope                = "${module.keyvault.id}/secrets/${each.value.secret}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.star_catch[each.value.app].principal_id
}

resource "time_sleep" "star_catch_roles" {
  count           = local.star_catch ? 1 : 0
  depends_on      = [azurerm_role_assignment.star_catch_secrets]
  create_duration = "60s"
}

module "star_catch_intake" {
  source     = "../modules/web_app"
  count      = local.star_catch ? 1 : 0
  depends_on = [time_sleep.star_catch_roles]

  name                         = "ca-star-catch-intake-${local.env}"
  resource_group_name          = local.rg
  container_app_environment_id = module.container_env.id
  identity_id                  = azurerm_user_assigned_identity.star_catch["intake"].id
  key_vault_uri                = module.keyvault.uri
  tags                         = local.tags

  container_name = "intake"
  image          = var.star_catch.image
  args           = ["intake"]
  target_port    = 8080
  cpu            = 0.25
  memory         = "0.5Gi"
  min_replicas   = 0
  max_replicas   = 1
  registry       = local.star_catch_registry

  secrets = {
    DATABASE_URL          = "database-url"
    GITHUB_WEBHOOK_SECRET = "github-webhook-secret"
  }
}
