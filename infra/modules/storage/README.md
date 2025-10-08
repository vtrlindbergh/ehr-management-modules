# Storage Module

This module provisions Azure Storage Account and related resources optimized for Hyperledger Fabric blockchain data with cost-effective configurations.

## Features

- **Storage Account**: Standard General-purpose v2 with Hot/Cool tiers
- **Blob Containers**: Organized storage for different blockchain components
- **File Share**: Shared configuration across VMs
- **Cost Optimization**: LRS replication, minimal retention policies
- **Security**: HTTPS-only, TLS 1.2, private containers

## Storage Structure

### Blob Containers
- **hyperledger-config**: Configuration files, certificates, genesis blocks
- **chaincode**: Smart contract code and packages
- **logs**: Application and blockchain logs
- **test-results**: Performance test results and reports

### File Share
- **shared-config**: Shared configuration files accessible via SMB/NFS
- **Quota**: 100 GB (adjustable)

## Usage

```hcl
module "storage" {
  source = "../../modules/storage"

  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  project_name       = "ehr-blockchain"
  environment        = "dev"

  replication_type = "LRS"    # Cost-optimized
  access_tier      = "Hot"    # For active data
  enable_backup    = false    # Disable for cost savings
}
```

## Storage Account Naming

Storage accounts require globally unique names. This module automatically generates a unique suffix:
- Format: `st{project_name}{environment}{random_suffix}`
- Example: `stehrblockchaindev7a9k2m1x`

## Access Patterns

### Development Phase
- **Hot Tier**: Active blockchain data, frequent access
- **LRS Replication**: Single region redundancy (lowest cost)

### Archive Phase (Optional)
- Move old logs to Cool/Archive tiers
- Implement lifecycle policies for cost optimization

## Connection Examples

### Azure CLI
```bash
# List containers
az storage container list --account-name <storage_account_name>

# Upload file
az storage blob upload \
  --account-name <storage_account_name> \
  --container-name hyperledger-config \
  --name genesis.block \
  --file ./genesis.block
```

### Mount File Share (Linux)
```bash
# Install cifs-utils
sudo apt-get install cifs-utils

# Create mount point
sudo mkdir /mnt/shared-config

# Mount file share
sudo mount -t cifs //<storage_account_name>.file.core.windows.net/shared-config /mnt/shared-config -o username=<storage_account_name>,password=<access_key>
```

## Cost Estimation (Monthly)

### Standard Configuration
- **Storage Account**: ~$2/month (base cost)
- **50 GB Hot Tier**: ~$1.15/month
- **File Share 100 GB**: ~$6/month
- **Transactions**: ~$0.50/month (estimated)
- **Total**: ~$9.65/month

### Cost Optimization Tips
1. Use lifecycle policies to move old data to Cool/Archive tiers
2. Regularly clean up test data and logs
3. Monitor transaction costs for high-frequency operations
4. Consider Cool tier for infrequently accessed data

## Security Features

- **HTTPS Only**: All connections encrypted in transit
- **TLS 1.2**: Minimum security protocol
- **Private Containers**: No public blob access
- **Access Keys**: Secure key-based authentication
- **Network Rules**: Can be configured for additional security