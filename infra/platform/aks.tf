resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.resource_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "main" {
  name                   = "aks-${local.resource_prefix}"
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  dns_prefix             = local.resource_prefix
  kubernetes_version     = var.kubernetes_version
  sku_tier               = "Standard" # Uptime SLA for production
  local_account_disabled = true        # Force Entra ID auth — no local kubeconfig
  tags                   = var.tags

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ips
  }

  # System node pool – runs kube-system, ALB controller, monitoring
  default_node_pool {
    name                         = "system"
    node_count                   = var.system_node_count
    vm_size                      = var.system_node_vm_size
    vnet_subnet_id               = azurerm_subnet.aks.id
    os_disk_size_gb              = 128
    os_disk_type                 = "Managed"
    max_pods                     = 50
    zones                        = [1, 2, 3]
    only_critical_addons_enabled = true

    node_labels = {
      "nodepool" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    service_cidr      = "10.2.0.0/16"
    dns_service_ip    = "10.2.0.10"
  }

  monitor_metrics {}

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  auto_scaler_profile {
    balance_similar_node_groups      = true
    max_graceful_termination_sec     = 600
    scale_down_delay_after_add       = "10m"
    scale_down_unneeded              = "10m"
    max_unready_nodes                = 3
    max_unready_percentage           = 45
  }

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [0, 1, 2, 3, 4]
    }
  }
}

# ── Standard pool: most business apps land here ─────────────
resource "azurerm_kubernetes_cluster_node_pool" "standard" {
  name                  = "standard"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.standard_node_vm_size
  node_count            = var.standard_node_min
  min_count             = var.standard_node_min
  max_count             = var.standard_node_max
  auto_scaling_enabled  = true
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_size_gb       = 128
  max_pods              = 50
  zones                 = [1, 2, 3]
  tags                  = var.tags

  node_labels = {
    "nodepool" = "standard"
    "tier"     = "standard"
  }
}

# ── High-memory pool: caches, in-memory stores, large APIs ──
resource "azurerm_kubernetes_cluster_node_pool" "highmem" {
  name                  = "highmem"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.highmem_node_vm_size
  node_count            = var.highmem_node_min
  min_count             = var.highmem_node_min
  max_count             = var.highmem_node_max
  auto_scaling_enabled  = true
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_size_gb       = 128
  max_pods              = 50
  zones                 = [1, 2, 3]
  tags                  = var.tags

  node_labels = {
    "nodepool" = "highmem"
    "tier"     = "highmem"
  }

  node_taints = ["workload=highmem:NoSchedule"]
}

# ── Compute pool: batch jobs, data processing (scales to 0) ─
resource "azurerm_kubernetes_cluster_node_pool" "compute" {
  name                  = "compute"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.compute_node_vm_size
  node_count            = var.compute_node_min
  min_count             = var.compute_node_min
  max_count             = var.compute_node_max
  auto_scaling_enabled  = true
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_size_gb       = 128
  max_pods              = 50
  zones                 = [1, 2, 3]
  tags                  = var.tags

  node_labels = {
    "nodepool" = "compute"
    "tier"     = "compute"
  }

  node_taints = ["workload=compute:NoSchedule"]
}
