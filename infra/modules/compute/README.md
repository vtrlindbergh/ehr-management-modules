# Compute Module

This module provisions Azure Virtual Machines optimized for Hyperledger Fabric blockchain deployment with cost optimization features.

## Features

- **Flexible Deployment Modes**:
  - `single`: One VM for all blockchain components (development)
  - `distributed`: Three VMs for realistic network topology (testing)

- **Cost Optimization**:
  - B-series VMs for burstable performance
  - Auto-shutdown scheduling
  - Standard SSD storage
  - Minimal resource allocation

- **Security**:
  - SSH key-based authentication
  - Network Security Groups with blockchain-specific rules
  - Private subnets with controlled access

- **Automation**:
  - Cloud-init scripts for Docker and Hyperledger setup
  - Automatic data disk formatting and mounting
  - Pre-configured directory structure

## VM Configurations

### Single Mode
- **hyperledger-all**: `Standard_B2s` (2 vCPUs, 4 GB RAM)
  - OS Disk: 64 GB Standard SSD
  - Data Disk: 128 GB Standard SSD
  - Purpose: All blockchain components on one VM

### Distributed Mode
- **orderer**: `Standard_B2s` (2 vCPUs, 4 GB RAM)
  - OS Disk: 32 GB Standard SSD
  - Data Disk: 64 GB Standard SSD
  - Purpose: Hyperledger Fabric orderer node

- **org1**: `Standard_B1s` (1 vCPU, 1 GB RAM)
  - OS Disk: 32 GB Standard SSD
  - Data Disk: 64 GB Standard SSD
  - Purpose: Organization 1 peer node

- **org2**: `Standard_B1s` (1 vCPU, 1 GB RAM)
  - OS Disk: 32 GB Standard SSD
  - Data Disk: 64 GB Standard SSD
  - Purpose: Organization 2 peer node

## Usage

```hcl
module "compute" {
  source = "../../modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  project_name       = "ehr-blockchain"
  environment        = "dev"

  subnet_ids = {
    orderer = module.network.subnet_ids["orderer"]
    org1    = module.network.subnet_ids["org1"]
    org2    = module.network.subnet_ids["org2"]
  }

  deployment_mode      = "single"  # or "distributed"
  enable_auto_shutdown = true
  auto_shutdown_time   = "1900"
}
```

## Prerequisites

- SSH key pair generated: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa`
- Network module deployed with required subnets

## Post-Deployment

1. Connect to VM: `ssh azureuser@<public_ip>`
2. Verify Docker: `docker --version`
3. Check setup: `cat /opt/hyperledger/cloud-init-complete`
4. Navigate to workspace: `cd /opt/hyperledger`

## Cost Estimation

### Single Mode (Monthly)
- VM: ~$31/month (Standard_B2s)
- Storage: ~$12/month (64GB OS + 128GB data)
- **Total**: ~$43/month

### Distributed Mode (Monthly)
- VMs: ~$47/month (1x B2s + 2x B1s)
- Storage: ~$22/month (3x 32GB OS + 3x 64GB data)
- **Total**: ~$69/month

*Actual costs will be lower with auto-shutdown and sporadic usage.*