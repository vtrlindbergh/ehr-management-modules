# Variables for the development environment
# These values can be overridden via terraform.tfvars or environment variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ehr-blockchain"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "North Central US"
}

variable "location_short" {
  description = "Short name for Azure region (used in resource naming)"
  type        = string
  default     = "northcentralus"
}

variable "owner" {
  description = "Resource owner/maintainer"
  type        = string
  default     = "student-researcher"
}

variable "department" {
  description = "Department responsible for resources"
  type        = string
  default     = "computer-science"
}

variable "purpose" {
  description = "Purpose of the infrastructure"
  type        = string
  default     = "academic-research"
}

# Network configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
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