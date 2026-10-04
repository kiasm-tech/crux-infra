terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  # Filled per environment: terraform init -backend-config=../envs/<env>.backend.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    # A deleted account otherwise keeps its name reserved for 48 hours.
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
  # CI can't register providers — it only owns the env resource group.
  resource_provider_registrations = "none"
  storage_use_azuread             = true
}
