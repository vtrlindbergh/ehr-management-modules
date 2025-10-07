# Network Module Variables
# EHR Blockchain Infrastructure - Networking Component

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection (costs extra - disabled for student account)"
  type        = bool
  default     = false
}

variable "enable_outbound_access" {
  description = "Enable default outbound internet access (may incur data transfer costs)"
  type        = bool
  default     = false
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for subnets"
  type = object({
    orderer = list(string)
    org1    = list(string)
    org2    = list(string)
  })
  default = {
    orderer = ["10.0.1.0/24"]
    org1    = ["10.0.2.0/24"]
    org2    = ["10.0.3.0/24"]
  }
}