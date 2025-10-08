# Network Module - Main Configuration
# EHR Blockchain Infrastructure - Networking for Hyperledger Fabric

# Virtual Network for Blockchain Infrastructure
resource "azurerm_virtual_network" "blockchain_vnet" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  # DDoS protection disabled for cost optimization (student account)
  # Note: DDoS protection plan requires additional configuration and costs
  # Disabled for academic/student environments

  tags = merge(var.common_tags, {
    Component = "networking"
    Purpose   = "blockchain-infrastructure"
  })
}

# Subnet for Orderer Node (Control Plane)
resource "azurerm_subnet" "orderer_subnet" {
  name                 = "subnet-orderer"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.blockchain_vnet.name
  address_prefixes     = var.subnet_address_prefixes.orderer

  # Cost optimization: Control outbound access via variable
  default_outbound_access_enabled = var.enable_outbound_access

  # No service endpoints needed for basic blockchain setup
  # service_endpoints = []  # Explicit empty to avoid accidental premium features
}

# Subnet for Organization 1 Peer
resource "azurerm_subnet" "org1_subnet" {
  name                 = "subnet-org1"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.blockchain_vnet.name
  address_prefixes     = var.subnet_address_prefixes.org1

  # Cost optimization: Control outbound access via variable
  default_outbound_access_enabled = var.enable_outbound_access
}

# Subnet for Organization 2 Peer
resource "azurerm_subnet" "org2_subnet" {
  name                 = "subnet-org2"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.blockchain_vnet.name
  address_prefixes     = var.subnet_address_prefixes.org2

  # Cost optimization: Control outbound access via variable
  default_outbound_access_enabled = var.enable_outbound_access
}

# Network Security Group for Blockchain Traffic
resource "azurerm_network_security_group" "blockchain_nsg" {
  name                = "nsg-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow Orderer port (7050) within VNet
  security_rule {
    name                       = "Allow-Orderer-Internal"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "7050"
    source_address_prefix     = var.vnet_address_space[0]
    destination_address_prefix = "*"
  }

  # Allow Peer gRPC port (7051) within VNet
  security_rule {
    name                       = "Allow-Peer-gRPC-Internal"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "7051"
    source_address_prefix     = var.vnet_address_space[0]
    destination_address_prefix = "*"
  }

  # Allow SSH access from internet for admin purposes
  security_rule {
    name                       = "Allow-SSH-External"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "22"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  # Allow SSH access within VNet for admin purposes
  security_rule {
    name                       = "Allow-SSH-Internal"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "22"
    source_address_prefix     = var.vnet_address_space[0]
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range         = "*"
    destination_port_range    = "*"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Component = "security"
    Purpose   = "blockchain-network-protection"
  })
}

# Associate NSG with Orderer Subnet
resource "azurerm_subnet_network_security_group_association" "orderer_nsg_association" {
  subnet_id                 = azurerm_subnet.orderer_subnet.id
  network_security_group_id = azurerm_network_security_group.blockchain_nsg.id
}

# Associate NSG with Org1 Subnet
resource "azurerm_subnet_network_security_group_association" "org1_nsg_association" {
  subnet_id                 = azurerm_subnet.org1_subnet.id
  network_security_group_id = azurerm_network_security_group.blockchain_nsg.id
}

# Associate NSG with Org2 Subnet
resource "azurerm_subnet_network_security_group_association" "org2_nsg_association" {
  subnet_id                 = azurerm_subnet.org2_subnet.id
  network_security_group_id = azurerm_network_security_group.blockchain_nsg.id
}