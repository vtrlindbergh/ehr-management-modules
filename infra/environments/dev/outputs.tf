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

output "subnet_ids" {
  description = "IDs of all subnets"
  value       = module.network.subnet_ids
}

# Storage outputs
output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage.storage_account_name
}

output "storage_containers" {
  description = "Created storage containers"
  value       = module.storage.storage_containers
}

output "file_share_name" {
  description = "Name of the shared configuration file share"
  value       = module.storage.file_share_name
}

# Compute outputs
output "vm_public_ips" {
  description = "Public IP addresses of the VMs"
  value       = module.compute.vm_public_ips
}

output "vm_private_ips" {
  description = "Private IP addresses of the VMs"
  value       = module.compute.vm_private_ips
}

output "ssh_connection_commands" {
  description = "SSH connection commands for each VM"
  value       = module.compute.ssh_connection_commands
}

output "deployment_mode" {
  description = "Current deployment mode"
  value       = module.compute.deployment_mode
}

output "vm_configurations" {
  description = "VM configuration details"
  value       = module.compute.vm_configurations
}