variable "subscription_id" {
  description = "Azure subscription that hosts Crux."
  type        = string
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "environments" {
  description = "One resource group per environment; CI is scoped to these."
  type        = list(string)
  default     = ["dev", "prod"]
}

variable "github_repository" {
  description = "owner/name of the repo whose workflows may deploy."
  type        = string
  default     = "kiasm-tech/crux-infra"
}

variable "budget_amount" {
  description = "Monthly subscription budget, in the billing currency."
  type        = number
  default     = 50
}

variable "budget_contact_emails" {
  type = list(string)
}

variable "admin_group_object_id" {
  description = "Entra group whose members get human access (tfstate, Key Vault secrets)."
  type        = string
  default     = "8bb1b7f9-1a8b-462b-8799-04f1efa369a6" # Founders
}
