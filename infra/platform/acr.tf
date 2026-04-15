resource "azurerm_container_registry" "main" {
  name                          = replace("acr${local.resource_prefix}", "-", "")
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false    # Only accessible via private endpoint
  retention_policy_in_days      = 30
  tags                          = var.tags
}

# Grant AKS pull access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

# Key Vault for platform secrets (TLS certs, connection strings)
resource "azurerm_key_vault" "main" {
  name                          = "kv-${local.resource_prefix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 30
  purge_protection_enabled      = true
  public_network_access_enabled = false    # Only accessible via private endpoint
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

data "azurerm_client_config" "current" {}

# Key Vault access is now scoped per-secret via Workload Identity.
# See infra/modules/workload-identity/ — each app's identity only
# gets "Key Vault Secrets User" on its specific secrets, not the
# entire vault.
