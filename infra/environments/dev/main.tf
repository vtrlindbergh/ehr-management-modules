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
  project_name = "ehr-blockchain"
  environment  = "dev"
  region       = "eastus"  # Cost-optimized region selection
  
  # Academic project tags for resource governance
  common_tags = {
    Project     = "EHR-Blockchain-Dissertation"
    Environment = local.environment
    Owner       = "vitor-lindbergh"
    Purpose     = "academic-research"
    Department  = "computer-science"
    Region      = local.region
  }
}

# Resource group (already exists, but managed by Terraform for consistency)
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project_name}-${local.environment}"
  location = local.region
  tags     = local.common_tags
}

# Output important values for use in other modules
output "resource_group_name" {
  description = "Name of the main resource group"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region for deployment"
  value       = azurerm_resource_group.main.location
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}