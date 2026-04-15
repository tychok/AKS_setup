# ═══════════════════════════════════════════════════════════════
# Reusable module: Entra ID Workload Identity for an AKS app
# ═══════════════════════════════════════════════════════════════
# Creates:
#   1. User Assigned Managed Identity
#   2. Federated Identity Credential (AKS OIDC → Managed Identity)
#   3. Key Vault Secrets User role assignment (if key_vault_id provided)
#
# Usage:
#   module "inventory_api_identity" {
#     source         = "../../modules/workload-identity"
#     app_name       = "inventory-api"
#     namespace      = "inventory"
#     resource_group = azurerm_resource_group.main.name
#     location       = azurerm_resource_group.main.location
#     aks_oidc_issuer_url = azurerm_kubernetes_cluster.main.oidc_issuer_url
#     key_vault_id   = azurerm_key_vault.main.id     # optional
#     tags           = var.tags
#   }
# ═══════════════════════════════════════════════════════════════

variable "app_name" {
  description = "Application name (must match Helm appName / ServiceAccount name)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace the app is deployed to"
  type        = string
}

variable "resource_group" {
  description = "Azure resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL (from azurerm_kubernetes_cluster.main.oidc_issuer_url)"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID (required if key_vault_secret_names is non-empty)"
  type        = string
  default     = ""
}

variable "key_vault_secret_names" {
  description = "List of Key Vault secret names this app is allowed to read"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

# ── Managed Identity ─────────────────────────────────────────
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.app_name}"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = var.tags
}

# ── Federated Identity Credential ────────────────────────────
# Links the Kubernetes ServiceAccount to the Azure Managed Identity
# via the AKS OIDC issuer. The subject must match:
#   system:serviceaccount:<namespace>:<service-account-name>
resource "azurerm_federated_identity_credential" "app" {
  name                          = "${var.app_name}-federated"
  user_assigned_identity_id     = azurerm_user_assigned_identity.app.id
  audience                      = ["api://AzureADTokenExchange"]
  issuer                        = var.aks_oidc_issuer_url
  subject                       = "system:serviceaccount:${var.namespace}:${var.app_name}"
}

# ── Key Vault access (per-secret scoping) ────────────────────
# Each role assignment is scoped to a single secret, so this
# identity can only read the secrets explicitly listed.
resource "azurerm_role_assignment" "kv_secret" {
  for_each             = toset(var.key_vault_secret_names)
  scope                = "${var.key_vault_id}/secrets/${each.value}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# ── Outputs ──────────────────────────────────────────────────
output "client_id" {
  description = "Client ID to set in values.yaml workloadIdentity.clientId"
  value       = azurerm_user_assigned_identity.app.client_id
}

output "principal_id" {
  description = "Principal ID (for additional role assignments)"
  value       = azurerm_user_assigned_identity.app.principal_id
}

output "identity_id" {
  description = "Full resource ID of the managed identity"
  value       = azurerm_user_assigned_identity.app.id
}
