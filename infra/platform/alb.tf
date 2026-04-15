# ═══════════════════════════════════════════════════════════════
# Application Gateway for Containers (AGC)
# ═══════════════════════════════════════════════════════════════
# Replaces NGINX Ingress with Azure-native L7 load balancing.
# The ALB Controller runs in-cluster and reconciles Gateway API
# resources (Gateway, HTTPRoute) against this AGC instance.
# ═══════════════════════════════════════════════════════════════

resource "azurerm_application_load_balancer" "main" {
  name                = "alb-${local.resource_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_application_load_balancer_subnet_association" "main" {
  name                         = "alb-subnet-assoc"
  application_load_balancer_id = azurerm_application_load_balancer.main.id
  subnet_id                    = azurerm_subnet.alb.id
}

resource "azurerm_application_load_balancer_frontend" "main" {
  name                         = "alb-frontend"
  application_load_balancer_id = azurerm_application_load_balancer.main.id
}

# ── Managed identity for ALB Controller (workload identity) ──
resource "azurerm_user_assigned_identity" "alb_controller" {
  name                = "id-alb-controller-${local.resource_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Federate the managed identity with the AKS OIDC issuer
resource "azurerm_federated_identity_credential" "alb_controller" {
  name                          = "alb-controller-federated"
  user_assigned_identity_id     = azurerm_user_assigned_identity.alb_controller.id
  audience                      = ["api://AzureADTokenExchange"]
  issuer                        = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject                       = "system:serviceaccount:azure-alb-system:alb-controller-sa"
}

# ── Role assignments ─────────────────────────────────────────
# ALB Controller needs Reader on the AGC resource
resource "azurerm_role_assignment" "alb_reader" {
  scope                = azurerm_application_load_balancer.main.id
  role_definition_name = "AppGw for Containers Configuration Manager"
  principal_id         = azurerm_user_assigned_identity.alb_controller.principal_id
}

# ALB Controller needs Network Contributor on the ALB subnet
resource "azurerm_role_assignment" "alb_subnet_contributor" {
  scope                = azurerm_subnet.alb.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.alb_controller.principal_id
}
