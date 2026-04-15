# ADR-005: Single reusable Helm chart for all apps

**Date:** 2026-04-14
**Status:** Accepted

## Context

With 100+ applications, the platform needs a consistent deployment model. Options:

- **Per-app Helm charts** — each app maintains its own chart
- **Single shared Helm chart** — one chart covering all apps, customised via `values.yaml`

## Decision

We use a **single reusable Helm chart** (`platform/helm-chart/`) for all business applications. Each app only provides a `values.yaml` file.

## Reasons

1. **Consistency** — every app gets the same Deployment, Service, HTTPRoute, HPA, PDB, NetworkPolicy, and ServiceAccount structure. Security hardening (non-root, read-only fs, seccomp) is baked in.
2. **Reduced duplication** — 100 apps share one set of templates. Bug fixes and improvements apply everywhere.
3. **Lower barrier to entry** — application teams only need to understand `values.yaml`. They never write Kubernetes manifests.
4. **Governance by default** — pod security context, resource limits, network policies, and rate limiting are enforced by the chart structure. Teams can't accidentally skip them.
5. **Platform team control** — the chart is owned by the platform team (`CODEOWNERS`). Changes are reviewed centrally.

## Consequences

- Apps with unusual requirements (sidecar containers, init containers, custom volumes) may need chart extensions. The chart should be designed for the 90% case; outliers can use `extraContainers` or `extraVolumes` escape hatches if added later.
- The chart must remain backward-compatible. Breaking changes to `values.yaml` affect all apps.
- Version pinning (via Chart.yaml `version`) is important to prevent unexpected changes during deployments.

## Alternatives Considered

- **Per-app Helm charts** — rejected. Leads to inconsistency, duplicated boilerplate, and no central enforcement of security and governance standards.
- **Kustomize** — viable but less expressive for parameterisation. Helm's templating + values model maps better to the "one chart, many apps" pattern.
- **Raw manifests** — rejected. No parameterisation, no lifecycle management, no easy rollback.
