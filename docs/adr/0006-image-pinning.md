# ADR 0006: Pin every image tag and automate bumps

- Status: Proposed
- Date: 2026-11-22

## Context

All four images (`nextcloud`, `mariadb`, `nginx`, `paulczar/omgwtfssl`) are
referenced without a tag, which means `latest`.

- Nextcloud only supports upgrading **one major version at a time**. A Pod
  restart that pulls a `latest` two majors ahead leaves the instance unable
  to start.
- A new MariaDB major can change on-disk formats and may not yet be supported
  by the running Nextcloud version.
- Two installs from the same commit can produce different systems, so bug
  reports are not reproducible.

## Decision

- Every image is pinned to an explicit version tag:
  `nextcloud:<major>.<minor>.<patch>-apache` and `mariadb:<major>.<minor>`
  (an LTS series listed as supported in the Nextcloud system requirements).
- Tags are set in one place (the Kustomize `images:` block).
- Renovate (or Dependabot) opens pull requests for new tags. Nextcloud major
  bumps are never auto-merged and are grouped separately from patch bumps.
- `imagePullPolicy` stays at the default (`IfNotPresent` for tagged images).

## Alternatives considered

- **Pin by digest.** Fully reproducible but unreadable for a teaching repo;
  Renovate can add digests later if wanted.
- **Pin only the major (`nextcloud:31`).** Prevents the skipped-major
  failure, but still upgrades silently on restart.
- **Stay on `latest`.** Not acceptable for a stateful application.

## Consequences

- Upgrades become a deliberate, reviewable commit.
- The repo needs regular (automated) maintenance, otherwise the pinned
  versions become outdated and insecure. If nobody will merge the bump PRs,
  that is an argument for archiving the repo instead
  ([ADR 0001](0001-project-scope.md)).
- The upgrade procedure must be documented
  ([spec 004](../specs/004-operations.md)).
