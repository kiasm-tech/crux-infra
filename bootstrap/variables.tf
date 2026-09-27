variable "subscription_id" {
  description = "Azure subscription that hosts Crux."
  type        = string
}

variable "location" {
  type    = string
  default = "westeurope"
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
