# Spec 006: Repository and supply-chain security

- Status: Draft
- Date: 2026-11-22

## Why this applies to a small repo

People copy these manifests onto machines that hold their private files, and
the README tells them to fetch files by URL from this repository. A
compromised or careless change here is executed with cluster-admin rights on
someone else's cluster. Once CI and automated dependency updates exist
(ADR 0006, ADR 0008), the workflow itself also becomes something to protect.

## Requirements

### GitHub Actions

- Third-party actions are pinned to a full commit SHA, with the version in a
  trailing comment. Renovate keeps the SHAs current.
- Every workflow sets `permissions: contents: read` at the top level and
  widens it per job only where needed.
- No workflow uses `pull_request_target`.
- No secrets are needed by the test workflow; if one is ever added, it is not
  exposed to pull requests from forks.

### Scanning in CI

| Check | Tool (suggested) | Fails the build on |
| --- | --- | --- |
| Manifest misconfiguration | `trivy config` or `kubescape` on the rendered overlays | High and critical findings |
| Committed secrets | `gitleaks` | Any finding outside the allow-list |
| Image vulnerabilities | `trivy image` on the pinned tags, scheduled weekly | Nothing; opens an issue instead |

Image scanning reports rather than fails, because the fix (a new upstream
tag) is outside this repository's control and arrives through Renovate.

The fake credentials in `overlays/local`
([ADR 0012](../adr/0012-local-quickstart-overlay.md)) are the only allow-list
entry.

### Repository settings

- Branch protection on the default branch: pull request required, CI
  required, no force pushes.
- Secret scanning and push protection enabled.
- Private vulnerability reporting enabled.
- `SECURITY.md` says how to report a problem and that only the latest
  release is supported.

### What users are told

The README's install instructions:

- reference a release tag, never the default branch
  ([ADR 0011](../adr/0011-versioning-and-support-policy.md));
- use `git clone` plus `kubectl apply -k`, not `wget` of individual raw
  files;
- include a short "before you expose this to the internet" checklist: real
  certificate, strong admin password, two-factor authentication enabled in
  Nextcloud, brute-force protection left on, backups tested.

## Out of scope

- Signing releases or generating SBOMs. Reasonable later, but there is no
  build artefact here to sign.
- Runtime security tooling in the cluster.

## Acceptance

- A pull request that adds `hostPath`, a `latest` tag or a plaintext
  password fails CI.
- All actions in `.github/workflows/` are SHA-pinned.
- The repository settings above are enabled (checked by hand; they are not
  stored in Git).
