# Spec 007: Helm path

- Status: Draft
- Date: 2026-11-22
- Implements: ADR 0013

## Goal

A user who prefers Helm gets the same architecture as the manifests path
with one `helm upgrade --install`, using the official Nextcloud chart and a
values file from this repository.

## Layout

```text
helm/
  README.md               # install, upgrade, how it maps to the manifests path
  values.yaml             # curated values for a real install (ingress + TLS)
  values-local.yaml       # counterpart of overlays/local: no ingress, port-forward
  CHART_VERSION           # the pinned chart version, read by Makefile and CI
```

## Rules for the values files

- **Keys come from the chart, not from memory.** Every key must exist in the
  `values.yaml` of the pinned chart version. CI enforces this by rendering
  with `helm template` and, if the chart ships a `values.schema.json`,
  through Helm's own validation.
- Only values that differ from the chart's defaults are set, each with a
  one-line comment saying why.
- No credentials in the file. The chart is pointed at an existing Secret
  with the same keys as on the manifests path
  ([ADR 0003](../adr/0003-secrets-handling.md)), so the user creates one
  Secret whichever path they choose.
- Chart version and Nextcloud image tag are both pinned and both tracked by
  Renovate. The image tag must match the one on the manifests path.

## Parity with the manifests path

"Same architecture" means the following hold on both paths. Where the chart
cannot do something, the row is marked as a known difference in
`helm/README.md` rather than silently dropped.

| Property | Manifests path | Helm path |
| --- | --- | --- |
| Nextcloud image and tag | Kustomize `images:` | chart image values |
| Apache variant | ADR 0009 | chart default or explicit |
| Credentials from a pre-created Secret | ADR 0003 | chart's existing-secret setting |
| MariaDB, pinned, with recommended flags | ADR 0007 | to be decided, see below |
| Persistent app volume and separate data volume | ADR 0010 | chart persistence settings |
| Background jobs through cron | Sidecar | chart's cron setting |
| Trusted domain, proxy and HTTPS overwrite settings | Spec 002 | chart host and config values |
| Ingress with cert-manager issuer | Spec 003 | chart ingress values |
| Probes including startup probe | Spec 001 | chart probe values |
| Resource requests and memory limit | Spec 001 | chart resources |
| Passes the smoke test | Spec 005 | Spec 005, same script |

## Database on the Helm path

Open design choice, to be settled when the chart is evaluated
(ADR 0013, "To verify"):

- **Option A, chart-managed database.** Fewest moving parts if the chart's
  bundled database is currently well maintained.
- **Option B, external database.** Apply only the MariaDB part of the
  manifests path (`kubectl apply -k base/mariadb`) and give the chart its
  address. More steps, but the database is identical on both paths and does
  not depend on a subchart.

Option B is the fallback and the likely outcome if the subchart situation is
unsatisfactory.

## Testing

- `make validate` renders both values files with `helm template` and runs
  the same kubeconform and kube-linter checks as for the overlays.
- `make smoke PATH_UNDER_TEST=helm` installs the chart with
  `values-local.yaml` into a kind cluster and runs `hack/smoke-test.sh`. The
  script takes namespace and Service name as parameters, since the chart's
  resource names differ.
- The upgrade test (spec 005) also runs for chart version bumps.

## Documentation

- README: a "which path" table near the top.

  | You want to | Use |
  | --- | --- |
  | Understand what a Nextcloud deployment consists of | Manifests path |
  | Try it on a laptop in five minutes | Either, with the local variant |
  | Run it for real and keep it updated | Helm path |
  | Manage it with Argo CD or Flux | Either; both are declarative |

- `helm/README.md`: install and upgrade commands referencing the chart by
  its pinned version, and the list of known differences.
- Operations runbook: moving between paths is backup and restore.

## Out of scope

- Authoring, packaging or publishing a chart (rejected in ADR 0013).
- Supporting every option of the official chart; the values file covers
  this repository's architecture only.

## Acceptance

- `helm upgrade --install` with `values-local.yaml` on a fresh kind cluster
  passes the smoke test.
- Every row of the parity table is either satisfied or listed as a known
  difference.
- A Renovate pull request bumping the chart version is tested by CI without
  manual steps.
