terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  # Local state on first run. Afterwards, uncomment and run
  # `terraform init -migrate-state` to move it next to the env states.
  # backend "azurerm" {
  #   resource_group_name  = "rg-crux-tfstate"
  #   storage_account_name = "<tfstate_storage_account output>"
  #   container_name       = "tfstate"
  #   key                  = "bootstrap.tfstate"
  #   use_azuread_auth     = true
  # }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

provider "azuread" {}
