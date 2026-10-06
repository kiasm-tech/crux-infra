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
    model   = string
    version = optional(string)
    # DataZoneStandard keeps prompts and answers inside the EU data zone (GDPR).
    sku      = optional(string, "DataZoneStandard")
    capacity = optional(number, 50)
  }))
  default = {
    "gpt-6-luna" = { model = "gpt-6-luna" }
  }
}

variable "ai_default_model" {
  description = "The deployment Crux and Star Catch use (OPENAI_MODEL)."
  type        = string
  default     = "gpt-6-luna"

  validation {
    condition     = contains(keys(var.ai_deployments), var.ai_default_model)
    error_message = "ai_default_model must be one of the ai_deployments."
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

variable "star_catch" {
  description = "The Star Catch backend; null leaves it out. Set its Key Vault secrets before the first apply."
  type = object({
    image             = optional(string, "ghcr.io/kiasm-tech/star-catch:main")
    registry_username = string
    github_app_id     = string
    # owner/name, comma-separated: always on, besides the repos switched on in Crux.
    repos = optional(string, "")
    # null = ai_default_model.
    classifier_model = optional(string)
    # The narration writer; null = the classifier's model.
    writer_model = optional(string)
    # e.g. { STAR_CATCH_MOCK_GITHUB = "true" } for a smoke test with recorded PRs.
    worker_env = optional(map(string), {})
  })
  default = null

  validation {
    condition     = try(var.star_catch.classifier_model, null) == null || contains(keys(var.ai_deployments), try(var.star_catch.classifier_model, ""))
    error_message = "star_catch.classifier_model must be one of the ai_deployments."
  }

  validation {
    condition     = try(var.star_catch.writer_model, null) == null || contains(keys(var.ai_deployments), try(var.star_catch.writer_model, ""))
    error_message = "star_catch.writer_model must be one of the ai_deployments."
  }
}
