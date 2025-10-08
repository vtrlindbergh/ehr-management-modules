variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for compute resources"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet IDs for VM placement"
  type = object({
    orderer = string
    org1    = string
    org2    = string
  })
}

variable "deployment_mode" {
  description = "Deployment mode: single (1 VM) or distributed (3 VMs)"
  type        = string
  default     = "single"
  validation {
    condition     = contains(["single", "distributed"], var.deployment_mode)
    error_message = "Deployment mode must be either 'single' or 'distributed'."
  }
}

variable "vm_admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ehr-hyperledger"
}

variable "enable_auto_shutdown" {
  description = "Enable auto-shutdown for cost optimization"
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "Auto-shutdown time in 24h format (e.g., '1900')"
  type        = string
  default     = "1900"
}

variable "auto_shutdown_timezone" {
  description = "Timezone for auto-shutdown"
  type        = string
  default     = "UTC"
}