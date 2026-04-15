variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "aks-platform"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.29"
}

# ── System node pool (kube-system, ALB controller, monitoring) ──
variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 3
}

variable "system_node_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D4s_v5"
}

# ── Standard app pool (majority of business apps) ───────────
variable "standard_node_min" {
  description = "Min nodes for the standard app pool"
  type        = number
  default     = 5
}

variable "standard_node_max" {
  description = "Max nodes for the standard app pool (autoscaler)"
  type        = number
  default     = 30
}

variable "standard_node_vm_size" {
  description = "VM size for standard workloads"
  type        = string
  default     = "Standard_D4s_v5"
}

# ── High-memory pool (caches, in-memory DBs, large APIs) ────
variable "highmem_node_min" {
  description = "Min nodes for the high-memory pool"
  type        = number
  default     = 2
}

variable "highmem_node_max" {
  description = "Max nodes for the high-memory pool"
  type        = number
  default     = 10
}

variable "highmem_node_vm_size" {
  description = "VM size for memory-intensive workloads"
  type        = string
  default     = "Standard_E4s_v5"
}

# ── Compute pool (batch jobs, data processing) ──────────────
variable "compute_node_min" {
  description = "Min nodes for the compute pool"
  type        = number
  default     = 0
}

variable "compute_node_max" {
  description = "Max nodes for the compute pool"
  type        = number
  default     = 10
}

variable "compute_node_vm_size" {
  description = "VM size for compute-intensive workloads"
  type        = string
  default     = "Standard_F8s_v2"
}

# ── Networking ───────────────────────────────────────────────
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/14"]
}

variable "aks_subnet_prefix" {
  description = "Subnet prefix for AKS nodes (large enough for 100+ apps)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "alb_subnet_prefix" {
  description = "Subnet prefix for Application Gateway for Containers (min /24)"
  type        = string
  default     = "10.1.0.0/24"
}

variable "private_endpoint_subnet_prefix" {
  description = "Subnet prefix for private endpoints (ACR, Key Vault)"
  type        = string
  default     = "10.1.1.0/24"
}

variable "api_server_authorized_ips" {
  description = "CIDR ranges allowed to reach the AKS API server. Set to your CI/CD runner and office IPs."
  type        = list(string)
  default     = []  # Empty = unrestricted — MUST be set for production
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
