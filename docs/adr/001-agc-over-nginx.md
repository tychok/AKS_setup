# ADR-001: Application Gateway for Containers over NGINX Ingress

**Date:** 2026-04-14
**Status:** Accepted

## Context

The platform needs an L7 ingress solution to route external traffic to 100+ business applications. The two main candidates were:

- **NGINX Ingress Controller** — widely adopted, Ingress API, community-maintained
- **Azure Application Gateway for Containers (AGC)** — Azure-managed, Gateway API, integrated with Azure networking

## Decision

We chose **AGC with the Kubernetes Gateway API** over NGINX Ingress Controller.

## Reasons

1. **Managed infrastructure** — AGC is an Azure PaaS resource. No NGINX pods to patch, scale, or monitor. The platform team doesn't need to manage ingress controller upgrades or CVE responses.
2. **Gateway API** — the successor to Ingress API. Supports multi-tenant routing (HTTPRoute per app, shared Gateway), explicit cross-namespace references, and richer traffic management.
3. **Azure integration** — AGC plugs directly into VNet subnets, supports Azure-native TLS termination, and integrates with Azure Monitor. No extra annotations or CRDs for Azure-specific features.
4. **Performance** — AGC handles TLS termination at the Azure fabric level, not in-cluster. This offloads CPU from the node pools.
5. **Security** — the ALB Controller authenticates via Workload Identity (OIDC). No shared secrets for the ingress layer.

## Consequences

- Teams must use `HTTPRoute` instead of `Ingress` manifests — the Helm chart handles this transparently.
- Gateway API CRDs must be installed during bootstrap.
- AGC is Azure-specific — this platform is not portable to other clouds without replacing the ingress layer.
- Rate limiting uses AGC-specific `RateLimitPolicy` CRDs rather than NGINX annotations.

## Alternatives Considered

- **NGINX Ingress Controller** — rejected due to operational overhead (patching, scaling, monitoring controller pods) and weaker multi-tenancy model.
- **Traefik** — good Gateway API support but still requires in-cluster management. No advantage over AGC in an Azure-only platform.
- **Azure Application Gateway (v2)** — predecessor to AGC. Slower reconciliation, less native Kubernetes integration, no Gateway API support.
