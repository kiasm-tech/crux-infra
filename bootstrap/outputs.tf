output "tfstate_storage_account" {
  value = azurerm_storage_account.tfstate.name
}

output "github_variables" {
  description = "Run these once to give the workflow its Azure identity."
  value       = <<-EOT
    gh variable set AZURE_CLIENT_ID --repo ${var.github_repository} --body ${azuread_application.github.client_id}
    gh variable set AZURE_TENANT_ID --repo ${var.github_repository} --body ${data.azurerm_client_config.current.tenant_id}
    gh variable set AZURE_SUBSCRIPTION_ID --repo ${var.github_repository} --body ${var.subscription_id}
  EOT
}
