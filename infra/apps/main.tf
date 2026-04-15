# ═══════════════════════════════════════════════════════════════
# Per-app identity provisioning — self-service via identity.yaml
# ═══════════════════════════════════════════════════════════════
# Each app declares its identity needs in:
#   apps/<app-name>/identity.yaml
#
# Terraform discovers all identity.yaml files automatically.
# Teams never need to edit this file — just add identity.yaml
# to their app folder and run: cd infra/apps && terraform apply
# ═══════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ── Import platform outputs ──────────────────────────────────
data "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

variable "resource_group_name" {
  description = "Resource group containing the AKS cluster"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the shared Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default = {
    project     = "aks-platform"
    environment = "dev"
  }
}

# ── Auto-discover apps from identity.yaml files ──────────────
locals {
  identity_files = fileset("${path.module}/../../apps", "*/identity.yaml")

  apps = {
    for f in local.identity_files :
    dirname(f) => yamldecode(file("${path.module}/../../apps/${f}"))
    if dirname(f) != "_template"
  }
}

# ── Create one Workload Identity per discovered app ──────────
module "app_identity" {
  for_each = local.apps

  source                 = "../modules/workload-identity"
  app_name               = each.key
  namespace              = each.value.namespace
  resource_group         = var.resource_group_name
  location               = var.location
  aks_oidc_issuer_url    = data.azurerm_kubernetes_cluster.main.oidc_issuer_url
  key_vault_id           = length(each.value.key_vault_secrets) > 0 ? data.azurerm_key_vault.main.id : ""
  key_vault_secret_names = each.value.key_vault_secrets
  tags                   = var.tags
}

# ── Outputs ──────────────────────────────────────────────────
# Use: terraform output -json app_client_ids
output "app_client_ids" {
  description = "Map of app name → Workload Identity client ID (set in values.yaml)"
  value = {
    for app, mod in module.app_identity : app => mod.client_id
  }
}
