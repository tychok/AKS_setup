# ADR-003: Per-secret Key Vault RBAC over vault-wide access

**Date:** 2026-04-14
**Status:** Accepted

## Context

Applications need secrets from Azure Key Vault (database passwords, API keys, connection strings). The question is how granularly to scope access.

Options:

- **Vault-wide access** — each app's Workload Identity gets `Key Vault Secrets User` on the entire vault
- **Per-vault isolation** — one Key Vault per team/namespace
- **Per-secret RBAC** — scope the role assignment to individual secrets within a shared vault

## Decision

We chose **per-secret RBAC** — each app's Workload Identity only gets `Key Vault Secrets User` scoped to `{vault_id}/secrets/{secret_name}` for each secret it declares.

## Reasons

1. **Least privilege** — `inventory-api` can read `InventoryDbConnectionString` but cannot read `InventoryDbPassword`. Vault-wide access would let any app read any secret.
2. **Single vault simplicity** — one Key Vault to manage, monitor, and back up. Per-vault isolation would mean 20+ vaults with separate access policies, diagnostics, and cost.
3. **Self-service via identity.yaml** — teams declare their secret names in a simple YAML file. Terraform discovers them and creates scoped role assignments automatically. No platform team intervention needed.
4. **Azure-native** — Azure RBAC supports secret-level scoping natively. No custom tooling or wrapper scripts required.

## Consequences

- Secrets must exist in Key Vault before apps can read them. The platform team (or a CI pipeline) must pre-create secrets.
- Secret names in `identity.yaml` must exactly match Key Vault secret names — there's no wildcard support.
- If a team needs access to many secrets, the `identity.yaml` list grows. This is acceptable — it serves as an explicit audit trail.

## Alternatives Considered

- **Vault-wide access** — rejected. Any app could read any other app's secrets. Unacceptable for multi-tenant platforms.
- **Per-vault isolation** — rejected. Operational overhead of managing 20+ vaults outweighs the isolation benefit, especially when per-secret RBAC achieves the same access control within a single vault.
