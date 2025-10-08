# Network Module Outputs
# EHR Blockchain Infrastructure - Networking Outputs

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.blockchain_vnet.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.blockchain_vnet.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.blockchain_vnet.address_space
}

output "orderer_subnet_id" {
  description = "ID of the orderer subnet"
  value       = azurerm_subnet.orderer_subnet.id
}

output "orderer_subnet_address_prefix" {
  description = "Address prefix of the orderer subnet"
  value       = azurerm_subnet.orderer_subnet.address_prefixes[0]
}

output "org1_subnet_id" {
  description = "ID of the org1 subnet"  
  value       = azurerm_subnet.org1_subnet.id
}

output "org1_subnet_address_prefix" {
  description = "Address prefix of the org1 subnet"
  value       = azurerm_subnet.org1_subnet.address_prefixes[0]
}

output "org2_subnet_id" {
  description = "ID of the org2 subnet"
  value       = azurerm_subnet.org2_subnet.id
}

output "org2_subnet_address_prefix" {
  description = "Address prefix of the org2 subnet"
  value       = azurerm_subnet.org2_subnet.address_prefixes[0]
}

output "network_security_group_id" {
  description = "ID of the network security group"
  value       = azurerm_network_security_group.blockchain_nsg.id
}

output "network_security_group_name" {
  description = "Name of the network security group"
  value       = azurerm_network_security_group.blockchain_nsg.name
}

output "subnet_ids" {
  description = "Map of subnet IDs"
  value = {
    orderer = azurerm_subnet.orderer_subnet.id
    org1    = azurerm_subnet.org1_subnet.id
    org2    = azurerm_subnet.org2_subnet.id
  }
}