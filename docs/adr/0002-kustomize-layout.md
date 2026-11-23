# ADR 0002: Kustomize base + example overlay

- Status: Proposed
- Date: 2026-11-22

## Context

Today a user downloads each file with `wget`, replaces placeholders such as
`<someMySqlPass>` and `<someFolderLocation>` by hand in `nano`, and runs
`kubectl create -f` once per file. The same value (database password, server
name, host directory) has to be typed into several files, and the files as
committed are not valid input for `kubectl apply` or for any linter.

## Decision

Restructure the manifests as a Kustomize base with an example overlay:

```text
base/                  # valid, placeholder-free manifests
  kustomization.yaml
  namespace.yaml
  mariadb/…
  nextcloud/…
overlays/example/      # the only place a user edits
  kustomization.yaml   # hostname, storage sizes, image tags
  secrets.env.example  # copied to secrets.env, which is git-ignored
```

Deployment becomes `kubectl apply -k overlays/example`. Kustomize ships with
`kubectl`, so there is no extra tool to install.

All resources go into a dedicated `nextcloud` namespace and carry the
`app.kubernetes.io/*` recommended labels.

## Alternatives considered

- **Helm chart.** Rejected by [ADR 0001](0001-project-scope.md).
- **Keep hand-edited files, improve the README.** Does not fix duplicated
  values or the inability to lint the committed files.
- **`envsubst` templates.** Small, but needs a wrapper script and keeps the
  committed files invalid.

## Consequences

- The committed manifests are valid YAML that CI can validate
  ([ADR 0008](0008-ci-validation.md)).
- Each setting is defined once.
- Breaking change for anyone following the old blog post; the README needs a
  migration note and the old layout should be tagged (`v1-legacy`) before the
  restructure.
- `kubernetes-yaml/` disappears; `nginx.conf` is removed entirely if
  [ADR 0005](0005-tls-and-ingress.md) is accepted.
