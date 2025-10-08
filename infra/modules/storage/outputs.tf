output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.hyperledger_storage.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.hyperledger_storage.id
}

output "storage_account_primary_connection_string" {
  description = "Primary connection string for the storage account"
  value       = azurerm_storage_account.hyperledger_storage.primary_connection_string
  sensitive   = true
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.hyperledger_storage.primary_access_key
  sensitive   = true
}

output "storage_containers" {
  description = "Created storage containers"
  value = {
    config      = azurerm_storage_container.config.name
    chaincode   = azurerm_storage_container.chaincode.name
    logs        = azurerm_storage_container.logs.name
    results     = azurerm_storage_container.results.name
  }
}

output "file_share_name" {
  description = "Name of the shared configuration file share"
  value       = azurerm_storage_share.shared_config.name
}

output "file_share_url" {
  description = "URL of the shared configuration file share"
  value       = azurerm_storage_share.shared_config.url
}

output "backup_vault_name" {
  description = "Name of the backup vault (if enabled)"
  value       = var.enable_backup ? azurerm_recovery_services_vault.backup_vault[0].name : null
}

output "storage_endpoints" {
  description = "Storage account service endpoints"
  value = {
    blob  = azurerm_storage_account.hyperledger_storage.primary_blob_endpoint
    file  = azurerm_storage_account.hyperledger_storage.primary_file_endpoint
    table = azurerm_storage_account.hyperledger_storage.primary_table_endpoint
    queue = azurerm_storage_account.hyperledger_storage.primary_queue_endpoint
  }
}