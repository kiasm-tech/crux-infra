variable "environment" {
  type = string
}

variable "location" {
  type    = string
  default = "northeurope"
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
