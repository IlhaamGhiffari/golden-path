terraform {
  required_version = ">= 1.5, < 2.0" # audit fix: upper bound guards against 2.x breakage

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "golden-path-state-rg"
    storage_account_name = "gpstateilhaam"
    container_name       = "tfstate"
    key                  = "golden-path.tfstate"
  }
}

provider "azurerm" {
  features {}
}
