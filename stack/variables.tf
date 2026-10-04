variable "environment" {
  type = string
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "ai_location" {
  description = "Region of the AI Services account; new models reach Sweden Central first."
  type        = string
  default     = "swedencentral"
}

variable "ai_deployments" {
  description = "Deployment name (= the model apps ask for) => model."
  type = map(object({
    model    = string
    version  = optional(string)
    sku      = optional(string, "GlobalStandard")
    capacity = optional(number, 50)
  }))
  default = {
    "gpt-5-mini"    = { model = "gpt-5-mini" }    # Star Catch classifier
    "gpt-5.3-codex" = { model = "gpt-5.3-codex" } # Crux generation
  }
}

variable "postgres_sku" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgres_allowed_ips" {
  type    = list(string)
  default = []
}

variable "web" {
  type = object({
    target_port  = optional(number, 80)
    cpu          = optional(number, 0.5)
    memory       = optional(string, "1Gi")
    min_replicas = optional(number, 0)
    max_replicas = optional(number, 2)
    env          = optional(map(string), {})
    # Env var name => Key Vault secret name. Create the secret first.
    secrets = optional(map(string), {})
    registry = optional(object({
      server          = string
      username        = string
      password_secret = string
    }))
  })
  default = {}
}
