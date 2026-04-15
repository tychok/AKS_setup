# ═══════════════════════════════════════════════════════════════
# Development environment
# ═══════════════════════════════════════════════════════════════
# Usage: terraform plan -var-file=environments/dev.tfvars

project_name       = "aks-platform"
location           = "eastus2"
environment        = "dev"
kubernetes_version = "1.29"

# Smaller pools for dev — cost savings
system_node_count    = 3
system_node_vm_size  = "Standard_D2s_v5"

standard_node_min    = 2
standard_node_max    = 10
standard_node_vm_size = "Standard_D2s_v5"

highmem_node_min     = 1
highmem_node_max     = 3
highmem_node_vm_size = "Standard_E2s_v5"

compute_node_min     = 0
compute_node_max     = 3
compute_node_vm_size = "Standard_F4s_v2"

# Dev: API server open for developer access (restrict in staging/prod)
api_server_authorized_ips = []

# Networking
vnet_address_space             = ["10.0.0.0/14"]
aks_subnet_prefix              = "10.0.0.0/16"
alb_subnet_prefix              = "10.1.0.0/24"
private_endpoint_subnet_prefix = "10.1.1.0/24"

tags = {
  project     = "aks-platform"
  environment = "dev"
  managed_by  = "terraform"
}
