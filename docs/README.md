# Project documentation

Planning documents for modernising this repository, written on 2026-11-22
against commit `0c6e488`. P0 and P1 are implemented (P1 on 2026-11-23); P2
and P3 are still proposals. See [`backlog.md`](backlog.md) for what has been
checked and how.

| Area | Contents |
| --- | --- |
| [`adr/`](adr/) | Architecture Decision Records: one decision per file, with the alternatives considered |
| [`specs/`](specs/) | Specifications: what the target state looks like in detail |
| [`backlog.md`](backlog.md) | Work items, ordered by priority, each with acceptance criteria |

## ADRs

ADRs 0001–0014 were accepted on 2026-11-23, when P1 was implemented. Deviations are recorded in the ADRs themselves.

| # | Decision | Status |
| --- | --- | --- |
| [0001](adr/0001-project-scope.md) | Stay a minimal, readable reference; do not compete with the Helm chart | Accepted |
| [0002](adr/0002-kustomize-layout.md) | Kustomize base + example overlay instead of hand-edited files | Accepted |
| [0003](adr/0003-secrets-handling.md) | Credentials live in a Kubernetes Secret that is never committed | Accepted |
| [0004](adr/0004-persistent-storage.md) | PersistentVolumeClaims instead of `hostPath` | Accepted |
| [0005](adr/0005-tls-and-ingress.md) | Ingress + cert-manager replace the proxy Pod and omgwtfssl | Accepted |
| [0006](adr/0006-image-pinning.md) | Pin every image tag; automate bumps | Accepted |
| [0007](adr/0007-mariadb-statefulset.md) | Run MariaDB as a StatefulSet | Accepted |
| [0008](adr/0008-ci-validation.md) | Validate manifests in CI | Accepted |
| [0009](adr/0009-apache-image-variant.md) | Use the Apache variant of the Nextcloud image | Accepted |
| [0010](adr/0010-separate-data-volume.md) | Keep user data on its own volume (amends 0004) | Accepted |
| [0011](adr/0011-versioning-and-support-policy.md) | Semantic version tags and a tested-versions table | Accepted |
| [0012](adr/0012-local-quickstart-overlay.md) | A quickstart overlay with no prerequisites (amends 0002) | Accepted |
| [0013](adr/0013-helm-support.md) | Helm support through the official chart, not a chart of our own (amends 0001) | Accepted |
| [0014](adr/0014-modern-pod-features.md) | Use current Pod features; state a minimum Kubernetes version | Accepted |

## Specs

| # | Spec |
| --- | --- |
| [001](specs/001-target-architecture.md) | Target architecture and repository layout |
| [002](specs/002-nextcloud-runtime.md) | Nextcloud runtime configuration |
| [003](specs/003-ingress-and-tls.md) | Ingress and TLS |
| [004](specs/004-operations.md) | Backup, restore and upgrades |
| [005](specs/005-local-development-and-testing.md) | Local development and testing |
| [006](specs/006-repository-security.md) | Repository and supply-chain security |
| [007](specs/007-helm-path.md) | Helm path: values for the official chart |

## Background

- [Kubernetes changes since 2018](kubernetes-changes-since-2018.md): what
  changed in the ecosystem since the manifests were written, and which ADR
  or work item deals with each change.

## Conventions

- ADR files are named `NNNN-short-title.md` and are never deleted. A reversed
  decision gets a new ADR, and the old one is marked `Superseded by NNNN`.
- ADR sections: Status, Context, Decision, Alternatives considered, Consequences.
- Work item IDs (`WI-nn`) are stable; finished items are ticked, not removed.
