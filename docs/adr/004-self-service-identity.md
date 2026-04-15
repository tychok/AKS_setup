# ADR-004: Self-service identity via identity.yaml

**Date:** 2026-04-14
**Status:** Accepted

## Context

Each app that needs Azure service access (Key Vault, SQL, Cosmos DB, Storage) requires a Workload Identity. The original approach required the platform team to manually add a Terraform module block in `infra/apps/main.tf` for every new app — a bottleneck that undermines self-service.

## Decision

Each app declares its identity needs in `apps/<app-name>/identity.yaml`. Terraform auto-discovers all `identity.yaml` files using `fileset()` + `yamldecode()` and creates Workload Identities via `for_each`.

```yaml
# apps/my-app/identity.yaml
namespace: my-team
key_vault_secrets:
  - MyDbConnectionString
```

## Reasons

1. **True self-service** — teams add a file to their own app folder. No shared `main.tf` to edit, no merge conflicts, no platform team approval needed for identity provisioning.
2. **Declarative** — the `identity.yaml` is the single source of truth for what Azure access an app needs. Easy to audit.
3. **Scalable** — works the same for 5 apps or 500 apps. Terraform's `for_each` handles dynamic module instantiation cleanly.
4. **GitOps-friendly** — the onboarding workflow generates `identity.yaml` alongside `values.yaml`. Everything is in Git.

## Consequences

- `terraform plan` output grows as more apps are added. This is expected and manageable.
- Removing an app requires deleting its `identity.yaml` — Terraform will destroy the identity on next apply.
- The `_template/identity.yaml` must be excluded from discovery (handled by filtering `dirname != "_template"`).

## Alternatives Considered

- **Manual module blocks in main.tf** — rejected. Creates a bottleneck; every new app needs a platform team PR.
- **Separate Terraform workspace per app** — rejected. Adds state management overhead and makes it harder to see the full picture.
- **Crossplane or ASO** — viable for in-cluster provisioning but adds CRD complexity. Terraform is already the standard for this platform.
