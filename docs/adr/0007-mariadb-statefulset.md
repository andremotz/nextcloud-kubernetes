# ADR 0007: Run MariaDB as a StatefulSet

- Status: Proposed
- Date: 2026-11-22

## Context

MariaDB runs as a single-replica Deployment with `strategy: Recreate`. That
is safe today only because of the `Recreate` strategy: with the default
`RollingUpdate`, two `mysqld` processes would briefly open the same data
directory.

The container also runs with image defaults, while the Nextcloud
documentation asks for `READ-COMMITTED` transaction isolation and row-based
binary logging.

## Decision

- MariaDB becomes a StatefulSet with `replicas: 1`, a headless Service and a
  `volumeClaimTemplate` ([ADR 0004](0004-persistent-storage.md)).
- The Service is renamed from `db` to `mariadb`, and Nextcloud's
  `MYSQL_HOST` follows.
- Container args: `--transaction-isolation=READ-COMMITTED`,
  `--binlog-format=ROW`, `--log-bin=binlog`.
- Readiness and liveness probes use the image's bundled `healthcheck.sh`.
- `MARIADB_AUTO_UPGRADE=1` is set so minor/major image bumps run
  `mariadb-upgrade` automatically.

## Alternatives considered

- **Keep the Deployment.** Works, but the at-most-one guarantee depends on
  nobody ever changing the strategy, and the PVC is managed separately.
- **A database operator (mariadb-operator).** Gives backups and HA, but adds
  a controller and CRDs; out of scope per
  [ADR 0001](0001-project-scope.md).
- **PostgreSQL instead of MariaDB.** Equally well supported by Nextcloud;
  switching would force a database migration on every existing user for no
  clear gain.

## Consequences

- Stable Pod identity (`mariadb-0`) and at-most-one semantics by
  construction.
- Existing installs need a data migration into the new PVC
  ([spec 004](../specs/004-operations.md)).
- StatefulSet `volumeClaimTemplates` cannot be resized by editing the
  StatefulSet; resizing means editing the PVC directly.
