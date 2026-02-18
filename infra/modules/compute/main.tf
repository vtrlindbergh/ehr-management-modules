# VM configurations based on deployment mode
locals {
  vm_configs = var.deployment_mode == "single" ? {
    hyperledger-all = {
      name        = "vm-${var.project_name}-all-${var.environment}"
      size        = "Standard_B2s"  # 2 vCPUs, 4 GB RAM
      subnet_id   = var.subnet_ids.orderer
      os_disk_size = 64
      data_disk_size = 128
    }
  } : {
    orderer = {
      name        = "vm-${var.project_name}-orderer-${var.environment}"
      size        = "Standard_B2s"  # 2 vCPUs, 4 GB RAM
      subnet_id   = var.subnet_ids.orderer
      os_disk_size = 32
      data_disk_size = 64
    }
    org1 = {
      name        = "vm-${var.project_name}-org1-${var.environment}"
      size        = "Standard_B2s"  # 2 vCPUs, 4 GB RAM (Fabric peer + chaincode needs >1GB)
      subnet_id   = var.subnet_ids.org1
      os_disk_size = 32
      data_disk_size = 64
    }
    org2 = {
      name        = "vm-${var.project_name}-org2-${var.environment}"
      size        = "Standard_B2s"  # 2 vCPUs, 4 GB RAM (Fabric peer + chaincode needs >1GB)
      subnet_id   = var.subnet_ids.org2
      os_disk_size = 32
      data_disk_size = 64
    }
  }
}

# Network Security Group for VMs
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "nsg-${var.project_name}-vm-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # SSH access
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Hyperledger Fabric Peer ports
  security_rule {
    name                       = "HyperledgerPeer"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7051"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Hyperledger Fabric Orderer ports
  security_rule {
    name                       = "HyperledgerOrderer"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7050"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # CouchDB port (if used)
  security_rule {
    name                       = "CouchDB"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5984"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "VM Security"
  }
}

# Public IPs for VMs
resource "azurerm_public_ip" "vm_public_ip" {
  for_each = local.vm_configs

  name                = "pip-${each.value.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    VMRole      = each.key
  }
}

# Network Interfaces
resource "azurerm_network_interface" "vm_nic" {
  for_each = local.vm_configs

  name                = "nic-${each.value.name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip[each.key].id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    VMRole      = each.key
  }
}

# Associate NSG to NICs
resource "azurerm_network_interface_security_group_association" "vm_nic_nsg" {
  for_each = local.vm_configs

  network_interface_id      = azurerm_network_interface.vm_nic[each.key].id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Data disks
resource "azurerm_managed_disk" "vm_data_disk" {
  for_each = local.vm_configs

  name                 = "disk-${each.value.name}-data"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = each.value.data_disk_size

  tags = {
    Environment = var.environment
    Project     = var.project_name
    VMRole      = each.key
    Purpose     = "Data"
  }
}

# Virtual Machines
resource "azurerm_linux_virtual_machine" "vm" {
  for_each = local.vm_configs

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value.size
  admin_username      = var.vm_admin_username

  # Cost optimization: Disable boot diagnostics
  boot_diagnostics {}

  # Disable password authentication
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm_nic[each.key].id,
  ]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = each.value.os_disk_size
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Cloud-init script for initial setup
  custom_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yml", {
    admin_username = var.vm_admin_username
    vm_role        = each.key
  }))

  tags = {
    Environment = var.environment
    Project     = var.project_name
    VMRole      = each.key
    AutoShutdown = var.enable_auto_shutdown ? "Enabled" : "Disabled"
  }
}

# Attach data disks to VMs
resource "azurerm_virtual_machine_data_disk_attachment" "vm_data_disk_attachment" {
  for_each = local.vm_configs

  managed_disk_id    = azurerm_managed_disk.vm_data_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[each.key].id
  lun                = "0"
  caching            = "ReadWrite"
}

# Auto-shutdown configuration (cost optimization)
resource "azurerm_dev_test_global_vm_shutdown_schedule" "vm_shutdown" {
  for_each = var.enable_auto_shutdown ? local.vm_configs : {}

  virtual_machine_id = azurerm_linux_virtual_machine.vm[each.key].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}