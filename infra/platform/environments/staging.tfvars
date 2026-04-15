# ═══════════════════════════════════════════════════════════════
# Staging environment
# ═══════════════════════════════════════════════════════════════
# Usage: terraform plan -var-file=environments/staging.tfvars
# Staging mirrors production sizing at reduced scale.

project_name       = "aks-platform"
location           = "eastus2"
environment        = "staging"
kubernetes_version = "1.29"

system_node_count    = 3
system_node_vm_size  = "Standard_D4s_v5"

standard_node_min    = 3
standard_node_max    = 15
standard_node_vm_size = "Standard_D4s_v5"

highmem_node_min     = 1
highmem_node_max     = 5
highmem_node_vm_size = "Standard_E4s_v5"

compute_node_min     = 0
compute_node_max     = 5
compute_node_vm_size = "Standard_F8s_v2"

# Staging: restrict to CI/CD and VPN only
api_server_authorized_ips = [
  # "203.0.113.0/24",   # Office/VPN
  # "198.51.100.10/32", # GitHub Actions runner
]

# Separate address space from dev to allow VNet peering
vnet_address_space             = ["10.4.0.0/14"]
aks_subnet_prefix              = "10.4.0.0/16"
alb_subnet_prefix              = "10.5.0.0/24"
private_endpoint_subnet_prefix = "10.5.1.0/24"

tags = {
  project     = "aks-platform"
  environment = "staging"
  managed_by  = "terraform"
}
