# EHR Blockchain Infrastructure - Development Environment

This directory contains the Terraform configuration for the development environment of the EHR Blockchain project.

## Prerequisites

1. Azure CLI installed and authenticated
2. Terraform installed (version 1.0+)
3. An Azure subscription (Azure for Students supported)

## Configuration

### Variables

The infrastructure is configured using variables to promote reusability and maintainability. Key configuration files:

- `variables.tf`: Variable definitions with descriptions and defaults
- `terraform.tfvars`: Environment-specific values (customize for your needs)

### Important Variables to Customize

1. **Region Configuration**: Azure for Students subscriptions have region restrictions
   ```hcl
   location       = "North Central US"  # Update based on your subscription
   location_short = "northcentralus"   # Corresponding short name
   ```

2. **Project Configuration**:
   ```hcl
   project_name = "ehr-blockchain"
   environment  = "dev"
   owner        = "your-name"  # Can be set via TF_VAR_owner environment variable
   ```

3. **Network Configuration**:
   ```hcl
   vnet_address_space = ["10.0.0.0/16"]
   subnet_address_prefixes = {
     orderer = ["10.0.1.0/24"]
     org1    = ["10.0.2.0/24"]
     org2    = ["10.0.3.0/24"]
   }
   ```

## Usage

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Review the plan**:
   ```bash
   terraform plan
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply
   ```

4. **Destroy resources** (when testing is complete):
   ```bash
   terraform destroy
   ```

## Architecture

The infrastructure includes:

- **Resource Group**: Container for all resources
- **Virtual Network**: Isolated network environment
- **Subnets**: Separate network segments for:
  - Orderer nodes (control plane)
  - Organization 1 peers
  - Organization 2 peers
- **Network Security Group**: Firewall rules for blockchain ports (7050, 7051)

## Cost Optimization

This configuration is optimized for Azure for Students subscriptions:

- DDoS protection disabled (saves ~$3,000/month)
- Outbound internet access controlled
- No premium networking features
- Strategic region selection for cost efficiency

## Customization

To customize for your environment:

1. **Update `terraform.tfvars`** with your specific values:
   ```bash
   # Edit terraform.tfvars with your configuration
   vim terraform.tfvars
   ```

2. **Adjust region** based on your subscription's available regions

**Security Note**: The `terraform.tfvars` file contains configuration values but no secrets. All authentication is handled via Azure CLI or environment variables.

## Troubleshooting

### Region Restrictions

If you encounter region restriction errors:

1. Test available regions:
   ```bash
   az network vnet create --resource-group test-rg --name test-vnet --location "Region Name" --address-prefixes 10.0.0.0/16
   ```

2. Update `terraform.tfvars` with an allowed region
3. Common available regions for Azure for Students: North Central US, South Central US

### Authentication Issues

Ensure Azure CLI is authenticated:
```bash
az login
az account show
```