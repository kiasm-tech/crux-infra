terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "container_app_environment_id" { type = string }
variable "identity_id" { type = string }
variable "key_vault_uri" { type = string }
variable "tags" { type = map(string) }
variable "image" { type = string }

variable "container_name" {
  type    = string
  default = "job"
}

variable "args" {
  type    = list(string)
  default = []
}

variable "cpu" {
  type    = number
  default = 0.5
}

variable "memory" {
  type    = string
  default = "1Gi"
}

variable "replica_timeout_in_seconds" {
  type    = number
  default = 600
}

variable "env" {
  description = "Plain env vars."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Env var name => Key Vault secret name. The secret must exist before apply."
  type        = map(string)
  default     = {}
}

variable "registry" {
  description = "Private registry (GHCR). password_secret is a Key Vault secret name."
  type = object({
    server          = string
    username        = string
    password_secret = string
  })
  default = null
}

variable "keda" {
  description = "Start executions from a KEDA rule; null = started by hand (az containerapp job start)."
  type = object({
    rule_type        = string
    metadata         = map(string)
    auth             = map(string) # trigger parameter => Key Vault secret name
    polling_interval = optional(number, 30)
    max_executions   = optional(number, 1)
  })
  default = null
}

locals {
  kv_secret_names = toset(concat(
    values(var.secrets),
    var.registry == null ? [] : [var.registry.password_secret],
    var.keda == null ? [] : values(var.keda.auth),
  ))
}

resource "azurerm_container_app_job" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = var.container_app_environment_id
  workload_profile_name        = "Consumption"
  replica_timeout_in_seconds   = var.replica_timeout_in_seconds
  replica_retry_limit          = 0
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  dynamic "secret" {
    for_each = local.kv_secret_names
    content {
      name                = secret.value
      key_vault_secret_id = "${var.key_vault_uri}secrets/${secret.value}"
      identity            = var.identity_id
    }
  }

  dynamic "registry" {
    for_each = var.registry == null ? [] : [var.registry]
    content {
      server               = registry.value.server
      username             = registry.value.username
      password_secret_name = registry.value.password_secret
    }
  }

  dynamic "manual_trigger_config" {
    for_each = var.keda == null ? [1] : []
    content {
      parallelism              = 1
      replica_completion_count = 1
    }
  }

  dynamic "event_trigger_config" {
    for_each = var.keda == null ? [] : [var.keda]
    content {
      parallelism              = 1
      replica_completion_count = 1
      scale {
        min_executions              = 0
        max_executions              = event_trigger_config.value.max_executions
        polling_interval_in_seconds = event_trigger_config.value.polling_interval
        rules {
          name             = event_trigger_config.value.rule_type
          custom_rule_type = event_trigger_config.value.rule_type
          metadata         = event_trigger_config.value.metadata
          dynamic "authentication" {
            for_each = event_trigger_config.value.auth
            content {
              trigger_parameter = authentication.key
              secret_name       = authentication.value
            }
          }
        }
      }
    }
  }

  template {
    container {
      name   = var.container_name
      image  = var.image
      args   = length(var.args) > 0 ? var.args : null
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secrets
        content {
          name        = env.key
          secret_name = env.value
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}

output "name" { value = azurerm_container_app_job.this.name }
