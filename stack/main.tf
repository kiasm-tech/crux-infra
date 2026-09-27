data "azurerm_client_config" "current" {}

# Created by bootstrap; CI is scoped to it.
data "azurerm_resource_group" "this" {
  name = "rg-crux-${var.environment}"
}

locals {
  env    = var.environment
  rg     = data.azurerm_resource_group.this.name
  suffix = substr(sha1("${data.azurerm_client_config.current.subscription_id}-${local.env}"), 0, 6)
  tags   = { app = "crux", env = local.env, managed_by = "terraform" }
}

module "keyvault" {
  source = "../modules/keyvault"

  name                = "kv-crux-${local.env}-${local.suffix}"
  resource_group_name = local.rg
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags
}

module "storage" {
  source = "../modules/storage"

  name                = "stcrux${local.env}${local.suffix}"
  resource_group_name = local.rg
  location            = var.location
  tags                = local.tags
}

module "postgres" {
  source = "../modules/postgres"

  name                = "psql-crux-${local.env}-${local.suffix}"
  resource_group_name = local.rg
  location            = var.location
  sku_name            = var.postgres_sku
  allowed_ips         = var.postgres_allowed_ips
  tags                = local.tags
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  key_vault_id = module.keyvault.id
  value        = module.postgres.database_url
}

module "container_env" {
  source = "../modules/container_env"

  name                = "cae-crux-${local.env}"
  resource_group_name = local.rg
  location            = var.location
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Web app identity: read secrets, read/write blobs
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "web" {
  name                = "id-crux-web-${local.env}"
  resource_group_name = local.rg
  location            = var.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "web_kv" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.web.principal_id
}

resource "azurerm_role_assignment" "web_blob" {
  scope                = module.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.web.principal_id
}

# Role assignments take a moment to reach Key Vault; the app's first revision
# fails to resolve its secrets without this.
resource "time_sleep" "web_roles" {
  depends_on      = [azurerm_role_assignment.web_kv, azurerm_role_assignment.web_blob]
  create_duration = "60s"
}

module "web" {
  source     = "../modules/web_app"
  depends_on = [time_sleep.web_roles, azurerm_key_vault_secret.database_url]

  name                         = "ca-crux-web-${local.env}"
  resource_group_name          = local.rg
  container_app_environment_id = module.container_env.id
  identity_id                  = azurerm_user_assigned_identity.web.id
  key_vault_uri                = module.keyvault.uri
  tags                         = local.tags

  target_port  = var.web.target_port
  cpu          = var.web.cpu
  memory       = var.web.memory
  min_replicas = var.web.min_replicas
  max_replicas = var.web.max_replicas
  registry     = var.web.registry

  env = merge({
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.web.client_id
    AZURE_STORAGE_ACCOUNT = module.storage.name
  }, var.web.env)

  secrets = merge({ DATABASE_URL = azurerm_key_vault_secret.database_url.name }, var.web.secrets)
}
