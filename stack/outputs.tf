output "web_url" {
  value = "https://${module.web.fqdn}"
}

output "key_vault_name" {
  value = module.keyvault.name
}

output "storage_account_name" {
  value = module.storage.name
}

output "postgres_fqdn" {
  value = module.postgres.fqdn
}

output "web_identity_client_id" {
  value = azurerm_user_assigned_identity.web.client_id
}

output "openai_base_url" {
  value = module.ai.openai_base_url
}

output "ai_location" {
  value = module.ai.location
}

output "ai_default_model" {
  value = var.ai_default_model
}

output "ai_deployments" {
  value = module.ai.deployments
}

output "star_catch_intake_url" {
  value = local.star_catch ? "https://${module.star_catch_intake[0].fqdn}" : null
}

output "star_catch_jobs" {
  value = local.star_catch ? { worker = module.star_catch_worker[0].name, migrate = module.star_catch_migrate[0].name } : null
}
