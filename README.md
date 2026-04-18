# AKS Application Platform - Hosting 100+ Business Applications

This project represents my vision on how organisations could implement an AKS platform at scale. The core idea: **a dedicated platform team owns the complexity** — infrastructure, security, networking, policies, monitoring — so that **application teams can focus purely on shipping their code**.

Application teams get full self-service: onboard a new app, declare its secrets and peers, deploy via a single Helm values file. They never touch Terraform, write network policies, or configure identities manually. At the same time, the organisational guardrails are non-negotiable and enforced automatically:

- **Isolation** — every namespace gets default-deny network policies, resource quotas, and scoped RBAC
- **Security** — TLS everywhere, private endpoints, pod security hardening, no privileged containers
- **Identity** — per-app Workload Identity with per-secret Key Vault RBAC, no stored credentials
- **Monitoring** — centralised Prometheus + Grafana with namespace-scoped dashboards and alerts
- **Governance** — OPA Gatekeeper policies for image sources, required labels, and resource limits
- **RBAC** — Entra ID-based access, local accounts disabled, API server restricted to authorised IPs

The platform does the heavy lifting. Teams just deploy.

## Architecture Overview

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│  Azure Subscription                                                              │
│                                                                                  │
│  ┌──────────────┐    ┌─────────────────────────────────────────────┐             │
│  │ Azure        │    │                AKS Cluster                  │             │
│  │ Container    │    │                                             │             │
│  │ Registry     │───▶│  ┌──────────┐   ┌────────────────────────┐ │             │
│  │ (ACR)        │    │  │  System   │   │    App Node Pools      │ │             │
│  │ 🔒 Private   │    │  │  Pool     │   │    (auto-scaled)       │ │             │
│  └──────────────┘    │  └──────────┘   │                        │ │             │
│                      │                  │  ┌───┐ ┌───┐ ┌───┐    │ │  ┌────────┐ │
│  ┌──────────────┐    │  ┌──────────┐   │  │ns1│ │ns2│ │...│100+ │ │  │ Azure  │ │
│  │ VNet         │    │  │  AGC     │   │  └───┘ └───┘ └───┘    │ │  │Monitor │ │
│  │  snet-aks    │───▶│  │  + TLS   │   └────────────────────────┘ │──│ + Log  │ │
│  │  snet-alb    │    │  └──────────┘                              │  │Analyti.│ │
│  │  snet-pe     │    │                                             │  └────────┘ │
│  └──────────────┘    │  ┌──────────┐   ┌───────────────────────┐  │             │
│                      │  │Gatekeeper│   │  Prometheus + Grafana  │  │             │
│  ┌──────────────┐    │  │  (OPA)   │   │  (monitoring)         │  │             │
│  │ Azure        │    │  └──────────┘   └───────────────────────┘  │             │
│  │ Key Vault    │    │                                             │             │
│  │ 🔒 Private   │    │  ┌──────────┐   ┌───────────────────────┐  │             │
│  └──────────────┘    │  │ cert-    │   │  Workload Identity    │  │             │
│                      │  │ manager  │   │  (OIDC per app)       │  │             │
│  ┌──────────────┐    │  └──────────┘   └───────────────────────┘  │             │
│  │ NSG Rules    │    └─────────────────────────────────────────────┘             │
│  │ + Private    │                                                                │
│  │   DNS Zones  │    API Server: restricted to authorized IPs only               │
│  └──────────────┘    Local accounts: disabled (Entra ID only)                    │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘

Each app gets:  Namespace → ResourceQuota → LimitRange → NetworkPolicy
                Deployment → Service → HTTPRoute (HTTPS) → HPA → PDB
                ServiceAccount (Workload Identity) → SecretProviderClass
                (all generated from a single Helm chart + values file)
```

## Project Structure

```text
├── infra/                          # Terraform – infrastructure as code
│   ├── platform/                   #   AKS, ACR, VNet, Key Vault, AGC, NSG, private endpoints
│   │   └── environments/           #   Per-environment tfvars (dev / staging / prod)
│   ├── modules/
│   │   └── workload-identity/      #   Reusable module: Entra ID Workload Identity per app
│   └── apps/                       #   Per-app identity provisioning (auto-discovers identity.yaml)
│
├── platform/                       # Kubernetes platform layer
│   ├── helm-chart/                 #   Reusable Helm chart (1 chart → 100 apps)
│   │   ├── Chart.yaml
│   │   ├── values.yaml             #   Sensible defaults
│   │   └── templates/              #   Deployment, Service, HTTPRoute, HPA, PDB, etc.
│   ├── gateway/                    #   Shared GatewayClass + Gateway (AGC) + cert-manager
│   ├── policies/                   #   OPA Gatekeeper constraints
│   └── namespace-template/         #   Per-namespace quotas, network isolation, RBAC
│
├── apps/                           # Per-app configuration (values only)
│   ├── _template/                  #   Onboarding template for new apps
│   ├── sample-api/                 #   Example: standalone API
│   ├── inventory-svc/              #   Example: API with DB peer communication
│   └── inventory-db/               #   Example: PostgreSQL (internal only)
│
├── src/SampleApi/                  # Example .NET 8 app (one of 100)
├── monitoring/                     # Centralised Prometheus + Grafana
├── docs/adr/                       # Architecture Decision Records (6 ADRs)
│
├── .github/
│   └── workflows/
│       ├── build-app.yml           #   Reusable build workflow (called per app)
│       ├── deploy-app.yml          #   Reusable deploy workflow
│       ├── onboard-app.yml         #   Self-service: onboard a new app
│       ├── deploy-platform.yml     #   Platform infra & shared services
│       └── sample-api.yml          #   CI pipeline for the sample API
│
├── .editorconfig                   # Consistent formatting (indent, line endings)
├── .pre-commit-config.yaml         # Pre-commit hooks (lint, secret scanning)
├── LICENSE                         # Apache 2.0
```

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (v2.50+)
- [Terraform](https://developer.hashicorp.com/terraform/install) (v1.5+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.28+)
- [Helm](https://helm.sh/docs/intro/install/) (v3.12+)
- [Docker](https://docs.docker.com/get-docker/)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- An Azure subscription with Contributor access

## Quick Start

### 1. Provision Platform Infrastructure

```bash
cd infra/platform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform plan -out=tfplan && terraform apply tfplan
```

### 2. Bootstrap Platform Services

```bash
# Connect to the cluster
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Install Gateway API CRDs, ALB Controller, Gatekeeper, Prometheus (see monitoring/README.md)
```

### 3. Onboard a New Application

```bash
# Copy the template and fill in your app details
cp -r apps/_template apps/my-new-app
# Edit apps/my-new-app/values.yaml

# Deploy with Helm
helm upgrade --install my-new-app platform/helm-chart \
  -f apps/my-new-app/values.yaml \
  --namespace my-new-app --create-namespace
```

### 4. Verify

```bash
kubectl get pods -A -l app.kubernetes.io/managed-by=Helm
kubectl get httproute -A
```

## Development Workflow & CI/CD

### Local Development

**Setup your development environment:**

```bash
make dev-setup  # Install tools, setup pre-commit hooks, run initial checks
```

**Build, test, and validate:**

```bash
make build-app          # Build .NET application
make test-app           # Run unit tests
make lint-all           # Run all linters (Terraform, Helm, YAML)
make validate-all       # Full validation suite
```

**Helper commands:**

```bash
make help              # Show all available commands
make help-detailed     # Show detailed usage examples
```

### Pre-Commit Hooks

This project uses **pre-commit** to catch issues before they're committed:

```bash
make install-pre-commit  # Install hooks
```

**Hooks run on every commit:**

- ✅ **Terraform**: Format check, validate, TFLint
- ✅ **Helm**: Lint, template validation
- ✅ **YAML**: Style validation (yamllint)
- ✅ **Secrets**: Detect and prevent accidental credential commits (gitleaks, detect-secrets)
- ✅ **General**: Trailing whitespace, file fixers, merge conflict detection, large file checks

**Skip hooks for a specific commit (if needed):**

```bash
git commit --no-verify
```

**Update hooks to latest versions:**

```bash
make pre-commit-update
```

### CI/CD Workflows

This project has **6 automated GitHub Actions workflows**:

#### 1. **Build & Test** (`.github/workflows/build-and-test.yml`)

- **Trigger**: Push/PR to `main` or `develop`
- **Steps**:
  - .NET build, restore, and test
  - Docker image build with multi-stage caching
  - Push image on merge to `main` (tagged with branch, commit, semver)

```bash
# View logs
gh workflow view build-and-test
gh workflow run build-and-test --ref develop
```

#### 2. **Container Security Scan** (`.github/workflows/container-scan.yml`)

- **Trigger**: Every commit on `main`/`develop`
- **Scans**:
  - **Trivy** (aquasecurity) — vulnerability scanning, uploads to GitHub Security tab
  - **Snyk** (optional) — requires `SNYK_TOKEN` secret

```bash
trivy image ghcr.io/your-org/sample-api:latest  # Scan locally
```

#### 3. **Terraform Validation** (`.github/workflows/terraform-validate.yml`)

- **Trigger**: Changes to `infra/`
- **Checks**:
  - Format compliance
  - Syntax validation
  - **TFLint** — style and best-practice checks
  - **Checkov** — policy-as-code (security, compliance)
  - Plans for dev, staging, prod (artifacts uploaded)

```bash
make tf-validate        # Validate syntax
make tf-lint            # Run TFLint locally
make tf-plan ENVIRONMENT=dev  # Generate plan for dev
```

#### 4. **Helm Validation** (`.github/workflows/helm-validate.yml`)

- **Trigger**: Changes to `platform/helm-chart/`
- **Checks**:
  - Helm lint
  - Template rendering
  - Dry-run install validation
  - **Kubesec** security scanning
  - Kube-score compliance checks

```bash
make helm-lint           # Lint chart
make helm-template       # Render templates
make helm-validate       # Dry-run deployment
```

#### 5. **Security & Compliance Scan** (`.github/workflows/security-scan.yml`)

- **Trigger**: Daily (2 AM UTC) + on PR
- **Scans**:
  - **OWASP Dependency Check** — detect known vulnerable dependencies
  - **CodeQL** — source code analysis (C#)
  - **TruffleHog** — secret detection in git history
  - Kubernetes manifest security checks

#### 6. **Deploy to Dev** (`.github/workflows/deploy-dev.yml`)

- **Trigger**: Push to `develop` branch
- **Steps**:
  - Build & push Docker image
  - Azure login (requires `AZURE_CREDENTIALS` secret)
  - Deploy via Helm to AKS

**Requires these GitHub Secrets:**

```
AZURE_CREDENTIALS          # Service principal JSON (az account set ... | jq)
AKS_CLUSTER_NAME          # Your AKS cluster name
AKS_RESOURCE_GROUP        # Your resource group
```

**Configure secrets:**

```bash
# Create service principal (if not exists)
az ad sp create-for-rbac --name "github-actions" \
  --role Contributor \
  --scopes /subscriptions/{subscription-id}

# Add to GitHub: Settings → Secrets and variables → Actions
```

### Infrastructure as Code (Terraform)

**Plan and apply infrastructure changes:**

```bash
make tf-plan ENVIRONMENT=dev        # Generate plan
make tf-apply ENVIRONMENT=dev       # Apply plan (confirm interactively)
make tf-destroy ENVIRONMENT=dev     # Destroy (confirm interactively)
```

**Supported environments**: `dev`, `staging`, `prod`

### Kubernetes & Helm

**Deploy locally (requires kubectl access):**

```bash
make helm-lint            # Validate chart
make helm-validate        # Dry-run deployment
make helm-install         # Deploy to current cluster
```

**Pod logs:**

```bash
make k8s-logs             # Tail logs from sample-api deployment
```

### Docker

**Build and scan container image:**

```bash
make build-docker         # Build image locally
make scan-docker          # Scan with Trivy
```

## Key Concepts for 100-App Scale

| Concept | Implementation | Why |
| --- | --- | --- |
| **One Helm chart, many apps** | `platform/helm-chart/` + per-app `values.yaml` | Consistency without duplication |
| **Namespace-per-app isolation** | `platform/namespace-template/` | Blast radius, RBAC, quotas |
| **Resource quotas** | `LimitRange` + `ResourceQuota` per namespace | Prevent noisy neighbours |
| **Policy enforcement** | OPA Gatekeeper in `platform/policies/` | No privileged pods, required labels, image source |
| **Tiered node pools** | `standard` / `highmem` / `compute` pools | Right-size nodes per workload |
| **Auto-scaling** | Cluster Autoscaler + HPA per app | Scale nodes & pods independently |
| **Reusable CI/CD** | Callable workflows in `.github/workflows/` | One pipeline definition, 100 callers |
| **Centralised monitoring** | Prometheus + namespace-scoped dashboards | One Grafana, filter by app |
| **Network policies** | Default-deny + allow AGC per namespace | Zero-trust networking |
| **Self-service onboarding** | `onboard-app.yml` workflow | Teams onboard without platform tickets |

## Cleanup

```bash
cd infra/platform
terraform destroy
```

---

## Detailed Guide

### Namespace Isolation Model

Each namespace is a **team/product isolation boundary**. Multiple apps (API, DB, worker, cache) share one namespace. Isolation works in three layers:

| Layer | Mechanism | Effect |
| --- | --- | --- |
| **Cross-namespace** | `default-deny-all` NetworkPolicy in namespace template | No traffic in or out of the namespace by default |
| **Inter-app** | Per-app ingress + egress NetworkPolicies (Helm chart) | Every pod starts fully isolated, even within a namespace |
| **Peer communication** | `allowEgressTo` / `allowIngressFrom` in values.yaml | Teams self-service open specific app→app channels |

**Example — inventory-api talks to inventory-db:**

```yaml
# apps/inventory-svc/values.yaml (the API)
networkPolicy:
  allowEgressTo:
    - app: inventory-db
      port: 5432

# apps/inventory-db/values.yaml (the DB)
networkPolicy:
  allowIngressFrom:
    - app: inventory-api
      port: 5432
```

Both sides must declare the relationship. Calico enforces both the ingress and egress policies.

### Entra ID Workload Identity

Each app gets its own Azure Managed Identity — no shared credentials, no stored secrets.

**Setup flow:**

1. Create `apps/my-app/identity.yaml` declaring the namespace and which Key Vault secrets the app needs:

   ```yaml
   namespace: my-team
   key_vault_secrets:
     - MyDbConnectionString
     - MyApiKey
   ```

2. Apply Terraform — it auto-discovers all `identity.yaml` files:

   ```bash
   cd infra/apps
   terraform apply
   terraform output -json app_client_ids
   ```

3. Set the client ID in the app's `values.yaml`:

   ```yaml
   workloadIdentity:
     enabled: true
     clientId: "<client-id-from-step-2>"
   ```

The Helm chart creates a ServiceAccount annotated with the client ID. AKS OIDC injects a short-lived token into the pod so it can authenticate to Azure services (Key Vault, SQL, Cosmos DB, Storage, etc.) without any stored credentials.

### Key Vault Secret Isolation

Each app's Workload Identity is scoped to **only the specific secrets it declares** — not the entire Key Vault. RBAC role assignments are created at the individual secret level:

```text
Scope: {key_vault_id}/secrets/{secret_name}
Role:  Key Vault Secrets User
```

This means:

- `inventory-api` can read `InventoryDbConnectionString` and `InventoryApiKey`, but **cannot** read `InventoryDbPassword`
- `inventory-db` can read `InventoryDbPassword`, but **cannot** read `InventoryApiKey`
- `sample-api` has no Key Vault access at all

The secret list is declared per-app in `identity.yaml` and enforced by Azure RBAC — no code changes needed in the Helm chart or CSI driver config.

**Example `identity.yaml` files:**

```yaml
# apps/inventory-svc/identity.yaml
namespace: inventory
key_vault_secrets:
  - InventoryDbConnectionString
  - InventoryApiKey

# apps/inventory-db/identity.yaml
namespace: inventory
key_vault_secrets:
  - InventoryDbPassword

# apps/sample-api/identity.yaml
namespace: sample
key_vault_secrets: []
```

### Application Gateway for Containers (AGC)

External traffic is handled by **Azure Application Gateway for Containers** via the **Kubernetes Gateway API**, replacing the legacy NGINX Ingress Controller.

- A single shared `Gateway` lives in the `gateway-system` namespace
- Each app creates an `HTTPRoute` that attaches to the Gateway
- Namespaces must have the `gateway-access: "true"` label (set automatically by the namespace template)

```yaml
# apps/my-app/values.yaml
gateway:
  enabled: true
  host: my-app.apps.yourdomain.com
  path: /
  rateLimitRPS: 50
```

Internal-only apps (e.g. databases) set `gateway.enabled: false`.

### Platform Security

The platform implements defence-in-depth across network, identity, and encryption layers.

#### TLS Everywhere

All external traffic is encrypted via **cert-manager** + **Let's Encrypt**:

- A `ClusterIssuer` (Let's Encrypt production) provisions TLS certificates automatically
- A wildcard `Certificate` covers `*.apps.yourdomain.com`
- The Gateway has two listeners: HTTP (port 80) and HTTPS (port 443)
- An `HTTPRoute` performs a **301 redirect from HTTP → HTTPS** — no plaintext traffic reaches apps
- The Helm chart defaults to `listenerName: https`, so all app routes attach to the HTTPS listener

To use a custom domain, change the `dnsNames` in `platform/gateway/gateway.yaml` and the `email` on the `ClusterIssuer`.

#### API Server Access Control

The AKS API server is restricted to a set of allowed IP ranges:

```hcl
# infra/platform/variables.tf
variable "api_server_authorized_ips" {
  default = []  # MUST be set for production
}
```

Set this to your CI/CD runner IPs and office/VPN ranges. An empty list leaves the API server unrestricted — **always configure this before going to production**.

Local accounts are disabled (`local_account_disabled = true`), so all `kubectl` access must go through **Entra ID** — there is no certificate-based backdoor.

#### Private Endpoints

Both **ACR** and **Key Vault** have public network access disabled. They are only reachable via private endpoints inside the VNet:

- `snet-private-endpoints` subnet (10.1.1.0/24) hosts the endpoints
- Private DNS zones (`privatelink.azurecr.io`, `privatelink.vaultcore.azure.net`) resolve to private IPs
- Key Vault has `network_acls` with `default_action = "Deny"` and `bypass = "AzureServices"`

This means container image pulls and secret retrieval never leave the Azure backbone network.

#### NSG Rules

The AKS subnet NSG has explicit allow/deny rules instead of relying on defaults:

| Direction | Rule | Source | Destination | Ports |
| --- | --- | --- | --- | --- |
| Inbound | Allow ALB | ALB subnet | AKS subnet | All (AGC → pods) |
| Inbound | Allow LB probes | AzureLoadBalancer | * | * |
| Inbound | Allow VNet | VirtualNetwork | VirtualNetwork | * |
| Inbound | **Deny all** | * | * | * |
| Outbound | Allow Azure | AKS subnet | AzureCloud | 443 |
| Outbound | Allow VNet | VirtualNetwork | VirtualNetwork | * |
| Outbound | Allow DNS | AKS subnet | * | 53 |
| Outbound | Allow HTTP/S | AKS subnet | Internet | 80, 443 |
| Outbound | Allow NTP | AKS subnet | * | 123 |
| Outbound | **Deny all** | * | * | * |

### Node Pool Strategy

| Pool | VM Size | Auto-scale | Taint | Use case |
| --- | --- | --- | --- | --- |
| **system** | Standard_D4s_v5 | Fixed (3) | `CriticalAddonsOnly` | kube-system, ALB controller, monitoring |
| **standard** | Standard_D4s_v5 | 5 → 30 | — | Most business apps |
| **highmem** | Standard_E4s_v5 | 2 → 10 | `workload=highmem` | Caches, in-memory stores, large APIs |
| **compute** | Standard_F8s_v2 | 0 → 10 | `workload=compute` | Batch jobs, data processing |

Apps declare their pool in values.yaml via `nodePool: standard | highmem | compute`. The Helm chart sets the correct `nodeSelector` and `tolerations` automatically.

### Self-Service Onboarding

Teams onboard new apps via the **Onboard New App** GitHub Actions workflow (`onboard-app.yml`). It accepts:

| Input | Description |
| --- | --- |
| `app-name` | Unique application name |
| `namespace` | Target namespace (team/product). Created if missing |
| `team` | Owning team |
| `host` | Gateway hostname (blank for internal-only) |
| `node-pool` | `standard` / `highmem` / `compute` |
| `peers` | Comma-separated peers (e.g. `my-db:5432,cache:6379`) |
| `identity-client-id` | Entra ID Workload Identity client ID |
| `key-vault-secrets` | Comma-separated Key Vault secret names (e.g. `MyDbPassword,MyApiKey`) |

The workflow generates:

- `apps/<app-name>/values.yaml` with all configuration
- `apps/<app-name>/identity.yaml` with namespace and secret list
- `.github/workflows/<app-name>.yml` per-app deploy pipeline
- A PR for review before merge

### OPA Gatekeeper Policies

Four policies enforce governance across all namespaces:

| Policy | File | Effect |
| --- | --- | --- |
| **Required labels** | `platform/policies/require-labels.yaml` | Deployments must have `team` and `app.kubernetes.io/name` |
| **Block privileged** | `platform/policies/block-privileged.yaml` | No privileged containers or host networking |
| **Allowed registries** | `platform/policies/allowed-registries.yaml` | Images must come from the organisation's ACR |
| **Require resource limits** | `platform/policies/require-resource-limits.yaml` | Every container must declare CPU and memory limits |

### Monitoring

Centralised **Prometheus + Grafana** (kube-prometheus-stack) with:

- **Namespace-scoped Grafana dashboard** — dropdown filters by namespace and team
- **Platform-wide alerts** — high CPU, memory, restart loops, pod failures
- Automatic service discovery via Kubernetes labels
- System namespaces (kube-system, azure-alb-system, gateway-system, monitoring) are excluded from app dashboards

To access Grafana locally:

```bash
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Open http://localhost:3000 (default: admin / prom-operator)
# Import monitoring/grafana-dashboard.json
```

### CI/CD Workflows

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `build-app.yml` | Called by per-app pipelines | Build Docker image, push to ACR |
| `deploy-app.yml` | Called by per-app pipelines | Helm upgrade into app namespace |
| `deploy-platform.yml` | Push to `infra/**`, `platform/policies/**`, `monitoring/**` | Terraform apply, install Gateway API + ALB Controller + Gatekeeper + Prometheus |
| `onboard-app.yml` | Manual (workflow_dispatch) | Generate app config + pipeline, create PR |
| `sample-api.yml` | Push to `apps/sample-api/**` | Example per-app pipeline (calls build + deploy) |

All workflows use **OIDC federation** for Azure authentication — no stored service principal secrets.

### Terraform Layout

```text
infra/
├── platform/           # Core infrastructure (run once)
│   ├── providers.tf    #   azurerm ~> 4.0, backend config
│   ├── main.tf         #   Resource group, locals
│   ├── aks.tf          #   AKS cluster + 4 node pools
│   ├── acr.tf          #   Container Registry + Key Vault (private endpoints, no public access)
│   ├── alb.tf          #   Application Gateway for Containers + ALB Controller identity
│   ├── networking.tf   #   VNet, subnets, NSG rules, private endpoints, private DNS zones
│   ├── variables.tf    #   All configurable parameters (incl. API server authorized IPs)
│   └── outputs.tf      #   Cluster name, ACR server, Key Vault, ALB ID
│
├── modules/
│   └── workload-identity/
│       └── main.tf     #   Reusable: Managed Identity + Federated Credential + per-secret KV role
│
└── apps/
    └── main.tf         #   Auto-discovers apps/*/identity.yaml, creates identities via for_each
```

`infra/platform/` is applied once by the platform team. `infra/apps/` auto-discovers all `apps/*/identity.yaml` files — teams never edit `main.tf` directly.
