# ADR-006: Private endpoints for ACR and Key Vault

**Date:** 2026-04-14
**Status:** Accepted

## Context

The platform uses Azure Container Registry (ACR) for container images and Azure Key Vault for secrets. By default, both services expose public endpoints accessible from the internet.

## Decision

Both ACR and Key Vault have **public network access disabled** and are only reachable via **private endpoints** within the VNet.

## Reasons

1. **Reduced attack surface** — even with RBAC in place, public endpoints are a target for credential stuffing, token replay, or zero-day exploits. Private endpoints remove internet accessibility entirely.
2. **Data exfiltration prevention** — container images and secrets never traverse the public internet. All traffic stays on the Azure backbone.
3. **Compliance** — many regulatory frameworks (SOC 2, ISO 27001, PCI DSS) require or recommend private network access for sensitive services.
4. **Defence in depth** — RBAC controls *who* can access. Private endpoints control *where* access comes from. Both layers are necessary.

## Implementation

- A dedicated `snet-private-endpoints` subnet (10.1.1.0/24) hosts the private endpoints
- Private DNS zones (`privatelink.azurecr.io`, `privatelink.vaultcore.azure.net`) resolve service names to private IPs inside the VNet
- Key Vault additionally has `network_acls` with `default_action = "Deny"` and `bypass = "AzureServices"`

## Consequences

- **Local development** — developers cannot pull images or access Key Vault from their machines unless connected via VPN or using Azure Bastion. The `terraform.tfvars.example` documents this.
- **CI/CD runners** — GitHub Actions runners must either be self-hosted in the VNet or use a VPN/ExpressRoute connection. Alternatively, ACR Tasks can build images inside Azure.
- **Slightly higher cost** — private endpoints incur a small per-hour and per-GB charge. Negligible for production workloads.

## Alternatives Considered

- **Public endpoints with IP whitelisting** — rejected. IP ranges change, are hard to maintain, and don't prevent lateral movement within Azure.
- **Service endpoints** — rejected. Service endpoints only restrict to a VNet/subnet level, don't provide private DNS resolution, and are being superseded by private endpoints.
- **Separate VNet for services** — rejected. Adds VNet peering complexity with no security benefit over private endpoints in the same VNet.
