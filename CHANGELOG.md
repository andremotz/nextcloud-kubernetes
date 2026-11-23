# Changelog

## Unreleased

Complete restructure. The previous layout is preserved at the `v1-legacy` tag.
Migrating an existing install needs manual steps; see "Migrating from
v1-legacy" in the README.

### Changed

- Kustomize base plus two overlays (`local`, `example`) replace the
  hand-edited files in `kubernetes-yaml/`.
- PersistentVolumeClaims replace `hostPath`; user data has its own volume.
- Credentials come from a Secret generated from a git-ignored file.
- MariaDB runs as a StatefulSet.
- TLS through an Ingress and cert-manager replaces the nginx proxy Pod and
  omgwtfssl.

### Added

- Cron sidecar; background jobs are set to "Cron" on install.
- Probes, resource requests, dropped capabilities, Pod Security `baseline`.
- Traefik component and Helm values (HSTS, `.well-known` redirects, upload
  timeout).
- `Makefile` with lint, validation and a kind-based smoke test.

## v1-legacy (2026-11-22)

Last version of the original layout, with fixes:

- Removed the Docker socket mount from the proxy Pod.
- Nextcloud uses the environment variables of the official image.
- nginx: 4G uploads, forwarded headers, HSTS, `.well-known` redirects.
- Pinned image versions; self-signed certificate valid for 365 days.
- README points to the official kubeadm guides.

## 2019-12-02

- Deployments use `apps/v1` with `selector.matchLabels`.

## 2018-07-31

- Initial version.
