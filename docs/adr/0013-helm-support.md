# ADR 0013: Helm support through the official chart, not a chart of our own

- Status: Accepted (2026-11-23; implemented on branch `p1-restructure`)
- Date: 2026-11-22
- Amends: [ADR 0001](0001-project-scope.md)

## Context

ADR 0001 ruled Helm out with one sentence. That deserves a proper look:
Helm is how most people install third-party software on Kubernetes today,
and a reader who arrives from a search engine in 2026 is likely to expect a
`helm install` path.

Facts that shape the decision:

- An official, actively maintained chart exists (`nextcloud/helm`). It
  already covers ingress, persistence, cron, Redis, external databases,
  metrics and probes.
- Helm itself changed since this repo was written: Helm 3 removed Tiller
  (2019), charts can be distributed as OCI artefacts (2022), and Helm 4 was
  released in late 2025.
- A chart is an API. Every value becomes something users depend on, so a
  chart costs more to maintain than the same resources as plain YAML.
- This repository has one maintainer and had no commits for seven years.

## Decision

Offer **two installation paths that produce the same architecture**, and
write no chart of our own:

1. **Manifests path** (existing plan): plain YAML with Kustomize. The path
   for learning what the pieces are.
2. **Helm path** (new): a curated, commented values file for the official
   chart, pinned to a specific chart version, in `helm/`. The path for
   people who want upgrades handled by a maintained chart.

Both paths are exercised by the same smoke test in CI
([spec 005](../specs/005-local-development-and-testing.md)), and the README
opens with a short "which path is for me" table. Details are in
[spec 007](../specs/007-helm-path.md).

ADR 0001's scope statement stays, with its first bullet changed from "no
Helm chart" to "no Helm chart of our own".

## Alternatives considered

- **Write and publish our own chart.** Gives full control and a single
  `helm install`. Costs: templates and helpers, `values.schema.json`, unit
  tests (`helm-unittest`), `chart-testing` lint and install runs, a release
  pipeline to an OCI registry, an Artifact Hub listing, generated values
  documentation, and a compatibility promise for every value. The result
  would compete with a chart that has more maintainers and more users. Only
  worth it if the official chart cannot express the target architecture.
- **Helm only; drop the plain manifests.** The repository would shrink to a
  values file and a README. Simple to maintain, but the teaching value, which
  is the reason to keep the repo at all, goes with it.
- **Kustomize inflating the Helm chart (`helmCharts:` with
  `--enable-helm`).** One tool for both paths, but it needs a non-default
  flag, hides the rendered output from the reader and is the least familiar
  option for both Helm and Kustomize users.
- **No Helm (ADR 0001 as written).** Leaves production users with a link and
  no tested starting point.

## Consequences

- Readers get a tested Helm starting point without this repo owning chart
  templates.
- The repo now tracks an upstream it does not control. Chart upgrades arrive
  as Renovate pull requests and are gated by the smoke test; a breaking
  chart release may need a values rewrite.
- Two paths must be kept in step. The parity table in spec 007 defines what
  "in step" means, so drift is visible.
- Switching an existing install from one path to the other is a backup and
  restore, not an in-place change, because resource names and volume layout
  differ. The operations runbook must say so.

## Verified 2026-11-23 (WI-37)

- Chart 9.4.5 (app version 35.0.3), released 2026-11-17. There were twelve
  releases between July and November 2026, the repository is active, and it
  had 135 open issues.
- MariaDB, PostgreSQL and Redis still come from Bitnami subcharts
  (`oci://registry-1.docker.io/bitnamicharts`). The Helm path therefore uses
  the external-database option (spec 007, option B) with `base/mariadb`.
- The chart supports a separate data PVC
  (`persistence.nextcloudData`), a cron sidecar (`cronjob.type: sidecar`),
  an existing Secret for admin and database credentials, hooks, a startup
  probe and extra init containers. Every parity row is covered; the
  differences are listed in `helm/README.md`.

## Originally listed to verify

- **How the official chart currently provides its database and Redis.** It
  has historically pulled these in as Bitnami subcharts, and Bitnami
  restricted its free image catalogue in 2025. If the bundled database is
  not a sound default any more, the values file should point the chart at
  the MariaDB StatefulSet from [ADR 0007](0007-mariadb-statefulset.md)
  through the chart's external-database settings instead.
- Whether the chart can mount user data on a separate volume
  ([ADR 0010](0010-separate-data-volume.md)) and run cron as a sidecar.

## Revisit when

The official chart is abandoned, or it cannot express something the target
architecture requires. Then "our own chart" becomes the better alternative.
