# Generate a random suffix for storage account name (globally unique requirement)
resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Storage Account for Hyperledger Fabric shared data
resource "azurerm_storage_account" "hyperledger_storage" {
  name                     = "stehr${var.environment}${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"
  access_tier              = var.access_tier

  # Cost optimization settings
  https_traffic_only_enabled     = true
  min_tls_version               = "TLS1_2"
  allow_nested_items_to_be_public = false

  # Disable unnecessary features for cost optimization
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
    versioning_enabled = false
    change_feed_enabled = false
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Hyperledger Fabric Shared Storage"
  }
}

# Container for Hyperledger Fabric configuration files
resource "azurerm_storage_container" "config" {
  name                  = "hyperledger-config"
  storage_account_name  = azurerm_storage_account.hyperledger_storage.name
  container_access_type = "private"
}

# Container for chaincode
resource "azurerm_storage_container" "chaincode" {
  name                  = "chaincode"
  storage_account_name  = azurerm_storage_account.hyperledger_storage.name
  container_access_type = "private"
}

# Container for logs and results
resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.hyperledger_storage.name
  container_access_type = "private"
}

# Container for performance test results
resource "azurerm_storage_container" "results" {
  name                  = "test-results"
  storage_account_name  = azurerm_storage_account.hyperledger_storage.name
  container_access_type = "private"
}

# File share for shared configuration (optional)
resource "azurerm_storage_share" "shared_config" {
  name                 = "shared-config"
  storage_account_name = azurerm_storage_account.hyperledger_storage.name
  quota                = 100 # 100 GB quota

  metadata = {
    environment = var.environment
    purpose     = "shared-hyperledger-config"
  }
}

# Recovery Services Vault (for backup if enabled)
resource "azurerm_recovery_services_vault" "backup_vault" {
  count = var.enable_backup ? 1 : 0

  name                = "rsv-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  storage_mode_type   = "LocallyRedundant"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Backup"
  }
}

# Backup policy for file shares (if backup enabled)
resource "azurerm_backup_policy_file_share" "backup_policy" {
  count = var.enable_backup ? 1 : 0

  name                = "policy-${var.project_name}-fileshare"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.backup_vault[0].name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = var.backup_retention_days
  }
}