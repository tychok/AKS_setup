# Architecture Decision Records

This folder contains Architecture Decision Records (ADRs) that document the key design choices made for this platform and the reasoning behind them.

ADRs follow the format from [Michael Nygard's article](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions):

- **Status** — Proposed, Accepted, Deprecated, Superseded
- **Context** — What is the problem or situation?
- **Decision** — What did we decide?
- **Consequences** — What are the trade-offs?

## Index

| # | Title | Status |
| - | ----- | ------ |
| 001 | [AGC over NGINX Ingress](001-agc-over-nginx.md) | Accepted |
| 002 | [Namespace per team, not per app](002-namespace-per-team.md) | Accepted |
| 003 | [Per-secret Key Vault RBAC](003-per-secret-kv-rbac.md) | Accepted |
| 004 | [Self-service identity via identity.yaml](004-self-service-identity.md) | Accepted |
| 005 | [Single Helm chart for all apps](005-single-helm-chart.md) | Accepted |
| 006 | [Private endpoints for ACR and Key Vault](006-private-endpoints.md) | Accepted |
