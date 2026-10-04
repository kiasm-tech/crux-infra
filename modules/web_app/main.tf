terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "container_app_environment_id" { type = string }
variable "identity_id" { type = string }
variable "key_vault_uri" { type = string }
variable "tags" { type = map(string) }

variable "container_name" {
  type    = string
  default = "web"
}

variable "args" {
  description = "Arguments to the image's entrypoint; none = its default command."
  type        = list(string)
  default     = []
}

variable "image" {
  description = "Initial image only — later deploys come from the app's CI."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "target_port" {
  type    = number
  default = 80
}

variable "cpu" {
  type    = number
  default = 0.5
}

variable "memory" {
  type    = string
  default = "1Gi"
}

variable "min_replicas" {
  type    = number
  default = 0
}

variable "max_replicas" {
  type    = number
  default = 2
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

locals {
  kv_secret_names = toset(concat(
    values(var.secrets),
    var.registry == null ? [] : [var.registry.password_secret],
  ))
}

resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
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

  ingress {
    external_enabled = true
    target_port      = var.target_port
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

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

output "fqdn" { value = azurerm_container_app.this.ingress[0].fqdn }
