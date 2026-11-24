# ADR 0010: Keep user data on its own volume

- Status: Accepted (2026-11-23; implemented on branch `p1-restructure`)
- Date: 2026-11-22
- Amends: [ADR 0004](0004-persistent-storage.md)

## Context

Today one volume is mounted at `/var/www/html`. It holds three different
kinds of content:

| Path | Content | Size | Can be recreated? |
| --- | --- | --- | --- |
| `/var/www/html` | Application code copied from the image | ~1 GB | Yes, from the image |
| `/var/www/html/config` | `config.php`, instance secrets | KB | No |
| `/var/www/html/data` | User files | Unbounded | No |

With a single volume, the volume has to be sized for user files, a backup
always includes a gigabyte of reproducible application code, and growing
storage means resizing the volume the application itself runs from.

## Decision

Two PersistentVolumeClaims for Nextcloud:

- `nextcloud-app`, mounted at `/var/www/html` (small, default 5Gi).
- `nextcloud-data`, mounted at `/var/www/html/data` (sized in the overlay,
  default 20Gi).

`config/` stays on the app volume. The data directory keeps its default
path, so no extra environment variable is needed.

## Alternatives considered

- **Single volume (ADR 0004 as first written).** Simplest; keeps the
  problems above.
- **Three volumes (app, config, data).** Cleanest separation and what the
  Helm chart offers through `subPath`s, but one more claim for a few
  kilobytes of configuration.
- **Data directory outside the web root via `NEXTCLOUD_DATA_DIR`.**
  Recommended for bare-metal installs where the web server could serve the
  directory by mistake; the image's `.htaccess` already blocks that path, so
  the gain here is small and it complicates migration from the old layout.

## Consequences

- The data volume can use a different, larger or cheaper StorageClass.
- Backups can treat data and application separately
  ([spec 004](../specs/004-operations.md) needs a matching update).
- Both claims are `ReadWriteOnce` and must land on the same node; with a
  node-local provisioner that is automatic, on multi-node clusters with
  zonal storage it can constrain scheduling.
- The cron sidecar must mount both volumes.
- Migration from the old `hostPath` layout moves `nc-pv/data` into the data
  claim and the rest into the app claim.
