# ADR 0011: Versioning and support policy

- Status: Proposed
- Date: 2026-11-22

## Context

The README says the manifests were "tested on Ubuntu 18.04 but should be
compatible with any Kubernetes-cluster". There are no tags or releases, so a
reader cannot tell which Kubernetes, Nextcloud or MariaDB versions a given
commit was meant for, and the blog post links to a moving `master`.

## Decision

**Compatibility statement.** The README carries a small table that is
updated with every release:

| | Tested |
| --- | --- |
| Kubernetes | the minor versions exercised by CI |
| Nextcloud | the pinned tag |
| MariaDB | the pinned tag |

CI ([ADR 0008](0008-ci-validation.md)) runs the smoke test against the
Kubernetes minor versions that are still supported upstream. Anything else
is "may work, untested".

**Releases.** The repository uses semantic version tags:

- **Major**: applying the new version to an existing install needs manual
  steps (data migration, renamed resources, Nextcloud major bump).
- **Minor**: new optional overlays or settings; Nextcloud or MariaDB minor
  bumps.
- **Patch**: fixes and patch-level image bumps.

Each release has a `CHANGELOG.md` entry; majors include upgrade notes.
The README's install instructions reference a release tag, not the default
branch.

**Maintenance expectation.** The README states plainly that this is a
single-maintainer, best-effort project, and from which date the pinned
versions were last verified.

## Alternatives considered

- **No releases, rolling default branch.** What exists today; gives readers
  no stable reference.
- **Mirror the Nextcloud version in the tag (e.g. `31.0.2-1`).** Makes the
  application version obvious, but hides whether a release needs manual
  migration, which is what matters most to someone running it.

## Consequences

- Readers and the blog post can link to a version that keeps working.
- A Nextcloud major bump forces a major release here, which correctly
  signals "read the upgrade notes".
- Someone has to cut releases; with Renovate and CI this is a tag and a
  changelog line.
