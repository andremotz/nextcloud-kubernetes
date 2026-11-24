# ADR 0001: Stay a minimal, readable reference

- Status: Accepted (2026-11-23; implemented on branch `p1-restructure`)
- Date: 2026-11-22
- Amended by: [ADR 0013](0013-helm-support.md) ("no Helm chart" becomes "no
  Helm chart of our own"; a values file for the official chart is in scope)

## Context

The repository started in 2018 as the companion to a blog post: seven files
that bring up Nextcloud, MariaDB and an nginx TLS proxy on a single-node
kubeadm cluster. Since then an official Nextcloud Helm chart
(`nextcloud/helm`) has matured and covers production concerns such as Redis,
cron, metrics, ingress and external databases.

The repository has no stated goal, so it is unclear whether a change such as
"add Redis" or "add HA" belongs here.

## Decision

The repository remains a **small set of plain manifests that a reader can
understand in one sitting**, aimed at single-node and homelab clusters. It is
a learning resource and a starting point, not a turnkey production
distribution.

Concretely:

- Plain YAML plus Kustomize ([ADR 0002](0002-kustomize-layout.md)); no Helm
  chart, no operator.
- Defaults must be safe and must actually work on a current cluster.
- The README points to the official Helm chart for production and HA use.
- Features that need more than a few extra resources (HA database, object
  storage, Collabora/OnlyOffice, metrics stack) are out of scope.

## Alternatives considered

- **Turn the repo into a Helm chart.** Duplicates the official chart with far
  fewer maintainers.
- **Archive the repo and link to the Helm chart.** Honest and cheap, but the
  blog post and its readers lose a working example, and plain manifests still
  have teaching value that a templated chart does not.
- **Leave it as is.** The current manifests no longer work unmodified on
  current clusters (see [backlog](../backlog.md), P0 items).

## Consequences

- Every proposed feature can be judged against "does a reader still
  understand the whole thing?".
- Users with production needs are sent elsewhere early instead of discovering
  the limits later.
- The cluster-installation walkthrough in the README is out of scope and is
  replaced by links (WI-16).
