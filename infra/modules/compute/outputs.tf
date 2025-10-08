output "vm_public_ips" {
  description = "Public IP addresses of the VMs"
  value = {
    for k, v in azurerm_public_ip.vm_public_ip : k => v.ip_address
  }
}

output "vm_private_ips" {
  description = "Private IP addresses of the VMs"
  value = {
    for k, v in azurerm_network_interface.vm_nic : k => v.private_ip_address
  }
}

output "vm_names" {
  description = "Names of the created VMs"
  value = {
    for k, v in azurerm_linux_virtual_machine.vm : k => v.name
  }
}

output "vm_ids" {
  description = "IDs of the created VMs"
  value = {
    for k, v in azurerm_linux_virtual_machine.vm : k => v.id
  }
}

output "ssh_connection_commands" {
  description = "SSH connection commands for each VM"
  value = {
    for k, v in azurerm_public_ip.vm_public_ip : k => "ssh ${var.vm_admin_username}@${v.ip_address}"
  }
}

output "vm_configurations" {
  description = "VM configuration details"
  value = {
    for k, v in local.vm_configs : k => {
      name = v.name
      size = v.size
      os_disk_size = v.os_disk_size
      data_disk_size = v.data_disk_size
    }
  }
}

output "deployment_mode" {
  description = "Current deployment mode"
  value = var.deployment_mode
}