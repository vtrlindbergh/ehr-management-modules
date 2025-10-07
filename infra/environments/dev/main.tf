# EHR Blockchain Infrastructure - Development Environment
# Academic Project: Master's Dissertation on Blockchain-based EHR Management
# Author: Vitor Lindbergh
# Security: Follows least privilege principle with scoped service principal

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  # TODO: Migrate to remote state when Azure storage issue is resolved
  # backend "azurerm" {
  #   resource_group_name  = "rg-ehr-blockchain-dev"
  #   storage_account_name = "ehrterraformstate"
  #   container_name       = "tfstate"
  #   key                  = "dev.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  
  # Skip automatic resource provider registration for Student accounts
  # This prevents timeout issues while maintaining functionality
  skip_provider_registration = true
  
  # Use service principal for automated deployments
  # Credentials will be provided via environment variables
  # This follows security best practices for CI/CD
}

# Local values for consistent naming and tagging
locals {
  # Academic project tags for resource governance
  common_tags = {
    Project     = "EHR-Blockchain-Dissertation"
    Environment = var.environment
    Owner       = var.owner
    Purpose     = var.purpose
    Department  = var.department
    Region      = var.location_short
  }
}

# Resource group (already exists, but managed by Terraform for consistency)
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = local.common_tags
}

# Network infrastructure module
module "network" {
  source = "../../modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  project_name       = var.project_name
  environment        = var.environment
  common_tags        = local.common_tags

  # Network configuration for blockchain (cost-optimized)
  vnet_address_space      = var.vnet_address_space
  subnet_address_prefixes = var.subnet_address_prefixes
  enable_ddos_protection  = false  # Cost optimization: ~$3,000/month savings
  enable_outbound_access  = false  # Cost optimization: Avoid data transfer charges
}

# Output important values for use in other modules
