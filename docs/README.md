# Project documentation

Planning documents for modernising this repository. Everything here was written
on 2026-11-22 against commit `0c6e488`; nothing in it is implemented yet.

| Area | Contents |
| --- | --- |
| [`adr/`](adr/) | Architecture Decision Records: one decision per file, with the alternatives considered |
| [`specs/`](specs/) | Specifications: what the target state looks like in detail |
| [`backlog.md`](backlog.md) | Work items, ordered by priority, each with acceptance criteria |

## ADRs

All ADRs are **Proposed** until the maintainer accepts them.

| # | Decision | Status |
| --- | --- | --- |
| [0001](adr/0001-project-scope.md) | Stay a minimal, readable reference; do not compete with the Helm chart | Proposed |
| [0002](adr/0002-kustomize-layout.md) | Kustomize base + example overlay instead of hand-edited files | Proposed |
| [0003](adr/0003-secrets-handling.md) | Credentials live in a Kubernetes Secret that is never committed | Proposed |
| [0004](adr/0004-persistent-storage.md) | PersistentVolumeClaims instead of `hostPath` | Proposed |
| [0005](adr/0005-tls-and-ingress.md) | Ingress + cert-manager replace the proxy Pod and omgwtfssl | Proposed |
| [0006](adr/0006-image-pinning.md) | Pin every image tag; automate bumps | Proposed |
| [0007](adr/0007-mariadb-statefulset.md) | Run MariaDB as a StatefulSet | Proposed |
| [0008](adr/0008-ci-validation.md) | Validate manifests in CI | Proposed |
| [0009](adr/0009-apache-image-variant.md) | Use the Apache variant of the Nextcloud image | Proposed |
| [0010](adr/0010-separate-data-volume.md) | Keep user data on its own volume (amends 0004) | Proposed |
| [0011](adr/0011-versioning-and-support-policy.md) | Semantic version tags and a tested-versions table | Proposed |
| [0012](adr/0012-local-quickstart-overlay.md) | A quickstart overlay with no prerequisites (amends 0002) | Proposed |
| [0013](adr/0013-helm-support.md) | Helm support through the official chart, not a chart of our own (amends 0001) | Proposed |
| [0014](adr/0014-modern-pod-features.md) | Use current Pod features; state a minimum Kubernetes version | Proposed |

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
