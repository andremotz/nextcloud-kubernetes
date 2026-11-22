# ADR 0008: Validate manifests in CI

- Status: Proposed
- Date: 2026-11-22

## Context

There is no automated check. The committed manifests contain placeholders
(`<someMySqlPass>`) and cannot be validated at all; whether the documented
install still works is only discovered when a reader tries it. Several of
the current defects (see [backlog](../backlog.md)) would have been caught by
a schema check or a smoke test.

## Decision

A GitHub Actions workflow runs on every pull request and on pushes to the
default branch:

1. `yamllint` on all YAML.
2. `kubectl kustomize overlays/example | kubeconform -strict` against the
   supported Kubernetes versions.
3. `kube-linter` (or `kubescape`) for security and best-practice findings:
   missing probes, missing resource requests, `hostPath`, privileged
   settings, `latest` tags.
4. `markdownlint` and a link checker on the docs.
5. **Smoke test:** create a `kind` cluster, apply the example overlay with
   test credentials, wait for the rollouts and assert that
   `/status.php` reports `"installed":true`.

Step 5 is the only one that proves the repository's central claim, so it is
required, not optional.

## Alternatives considered

- **Lint only, no smoke test.** Fast, but a manifest can be schema-valid and
  still not boot Nextcloud (the current environment-variable problem is an
  example).
- **Local pre-commit hooks only.** Useful in addition, but not enforced for
  contributors.

## Consequences

- Depends on [ADR 0002](0002-kustomize-layout.md): validation needs
  placeholder-free manifests.
- Image-bump pull requests ([ADR 0006](0006-image-pinning.md)) are tested
  before merge, which makes automated dependency updates safe enough to use.
- The smoke test adds a few minutes per run; the ingress/TLS path is not
  covered unless an ingress controller is installed in the `kind` cluster
  (follow-up).
