# Development Environment Outputs
# These outputs can be used by other modules or for reference

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.main.location
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

# Network outputs
output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.network.vnet_name
}

output "orderer_subnet_id" {
  description = "ID of the orderer subnet"
  value       = module.network.orderer_subnet_id
}

output "org1_subnet_id" {
  description = "ID of the org1 subnet"
  value       = module.network.org1_subnet_id
}

output "org2_subnet_id" {
  description = "ID of the org2 subnet"
  value       = module.network.org2_subnet_id
}