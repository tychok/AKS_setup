# ADR-002: Namespace per team, not per app

**Date:** 2026-04-14
**Status:** Accepted

## Context

With 100+ applications, namespace strategy has a major impact on isolation, RBAC, and operational complexity. The two options were:

- **Namespace per app** — every application gets its own namespace
- **Namespace per team/product** — a team's related apps (API, DB, worker, cache) share one namespace

## Decision

We chose **namespace per team/product domain**.

## Reasons

1. **Reduced namespace sprawl** — 100 apps across 20 teams means ~20 namespaces instead of 100+. Easier to manage quotas, RBAC bindings, and monitoring dashboards.
2. **Simpler peer communication** — apps within a team (e.g. `inventory-api` and `inventory-db`) naturally need to talk to each other. Within a namespace, NetworkPolicy peer rules are simpler and don't require cross-namespace references.
3. **Shared RBAC** — one RoleBinding per namespace covers the whole team. No need to manage per-app bindings.
4. **Resource sharing** — a team's apps share a ResourceQuota, which is more flexible than per-app limits that are hard to right-size.

## Consequences

- **Inter-app isolation within a namespace** is enforced by NetworkPolicy (default-deny + explicit peer declarations in `values.yaml`), not by namespace boundaries.
- Teams must coordinate namespace-level resources (quota usage, label conventions).
- The `allowIngressFrom` / `allowEgressTo` pattern in the Helm chart is essential — without it, apps in the same namespace could communicate freely.

## Alternatives Considered

- **Namespace per app** — rejected due to namespace explosion (100+ namespaces), duplicated RBAC/quota configuration, and complex cross-namespace NetworkPolicies for apps that need to communicate.
- **Single shared namespace** — rejected. No isolation whatsoever.
