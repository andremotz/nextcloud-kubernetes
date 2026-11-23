# ADR 0003: Credentials in a Kubernetes Secret, never in Git

- Status: Accepted (2026-11-23; implemented on branch `p1-restructure`)
- Date: 2026-11-22

## Context

`db-deployment.yaml` and `nc-deployment.yaml` carry the MariaDB user
password, the MariaDB root password and the Nextcloud admin password as
plain `env.value` entries. Users are told to edit the files in place, so the
passwords end up in the Deployment spec (readable by anyone with `get
deployment`) and, for anyone who forks the repo, very likely in Git.

## Decision

- One Secret, `nextcloud-credentials`, holds `mariadb-password`,
  `mariadb-root-password`, `nextcloud-admin-user` and
  `nextcloud-admin-password`.
- Containers read them through `env.valueFrom.secretKeyRef`.
- The Secret is produced by a Kustomize `secretGenerator` from
  `overlays/example/secrets.env`. That file is git-ignored; a
  `secrets.env.example` with empty values is committed.
- The README shows how to generate strong values
  (`openssl rand -base64 24`).

## Alternatives considered

- **Sealed Secrets / SOPS / External Secrets.** Better for GitOps, but each
  needs a controller or key management, which is beyond a minimal reference
  ([ADR 0001](0001-project-scope.md)). The README can mention them as the
  next step.
- **`kubectl create secret` by hand.** Works, but splits the install into
  imperative and declarative halves.
- **`*_FILE` variables with a mounted Secret volume.** Supported by both
  images and slightly safer than environment variables; more YAML for little
  gain here. Can be revisited.

## Consequences

- No credential appears in any committed file or in a Deployment spec.
- `secretGenerator` appends a content hash to the Secret name, so changing a
  value rolls the Pods automatically. Note that changing the *database*
  password this way does not change it inside an already initialised MariaDB;
  the operations spec covers rotation.
- Secrets are still only base64-encoded in etcd unless the cluster enables
  encryption at rest. The README should say so.
