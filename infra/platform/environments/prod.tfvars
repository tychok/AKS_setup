# ═══════════════════════════════════════════════════════════════
# Production environment
# ═══════════════════════════════════════════════════════════════
# Usage: terraform plan -var-file=environments/prod.tfvars
# Production uses full-scale node pools and locked-down access.

project_name       = "aks-platform"
location           = "westeurope"
environment        = "prod"
kubernetes_version = "1.29"

system_node_count    = 3
system_node_vm_size  = "Standard_D4s_v5"

standard_node_min    = 5
standard_node_max    = 30
standard_node_vm_size = "Standard_D4s_v5"

highmem_node_min     = 2
highmem_node_max     = 10
highmem_node_vm_size = "Standard_E4s_v5"

compute_node_min     = 0
compute_node_max     = 10
compute_node_vm_size = "Standard_F8s_v2"

# Production: MUST restrict to CI/CD runners and VPN only
api_server_authorized_ips = [
  # "203.0.113.0/24",   # Office/VPN — REQUIRED
  # "198.51.100.10/32", # GitHub Actions runner — REQUIRED
]

# Separate address space for prod isolation
vnet_address_space             = ["10.8.0.0/14"]
aks_subnet_prefix              = "10.8.0.0/16"
alb_subnet_prefix              = "10.9.0.0/24"
private_endpoint_subnet_prefix = "10.9.1.0/24"

tags = {
  project     = "aks-platform"
  environment = "prod"
  managed_by  = "terraform"
}
