# Spec 004: Backup, restore and upgrades

- Status: Draft
- Date: 2026-11-22

The repository currently documents installation only. A stateful service
without a tested restore path and a safe upgrade path is not usable beyond a
demo, so both are specified here and delivered as `docs/operations.md`
runbooks.

## Backup

What must be captured, consistently:

1. The MariaDB database `nextcloud`.
2. The Nextcloud volume (`config/`, `data/`, installed apps).

Procedure (manual runbook first, automation optional):

1. `occ maintenance:mode --on`
2. `mariadb-dump --single-transaction nextcloud` from the `mariadb-0` Pod
   to a file outside the cluster.
3. Copy or snapshot the Nextcloud volume (CSI `VolumeSnapshot` where the
   storage driver supports it, otherwise `tar` through `kubectl exec`).
4. `occ maintenance:mode --off`

Optional follow-up (WI-17): a `CronJob` that performs the database dump
nightly into a separate PVC with a retention count.

## Restore

1. Scale the Nextcloud Deployment to 0.
2. Restore the volume contents.
3. Drop and recreate the database, import the dump.
4. Scale to 1, then `occ maintenance:data-fingerprint`.

The runbook is only accepted once it has been executed end to end on a test
cluster.

## Upgrades

Rules:

- One Nextcloud **major version per step**; never skip a major.
- Take a backup first.
- Bump the image tag in the overlay and apply. The image's entrypoint runs
  the upgrade when it sees a newer version than the one in the volume.
- Afterwards: `occ db:add-missing-indices`, check the admin overview.
- MariaDB: move one release series at a time and only to a series the
  running Nextcloud version supports.

The Deployment keeps `strategy: Recreate` so the old and new versions never
run against the same volume at once.

## Credential rotation

Changing `mariadb-password` in the Secret does not change the password
inside an initialised database. Rotation is: `ALTER USER` in MariaDB, update
the Secret, update `dbpassword` in Nextcloud's `config.php` (the environment
variable is only read on first install), restart.

## Migration from the 2018/2019 layout

For users of the current `hostPath` manifests:

1. Enable maintenance mode and dump the database.
2. Delete the old Deployments, Services and Pods. The host directories stay
   in place.
3. Apply the new overlay with the **same** database credentials and a
   Nextcloud image tag of the **same major version** that was running.
4. Scale Nextcloud to 0, copy the old `nc-pv` contents into the new PVC and
   import the dump into `mariadb-0`.
5. Scale to 1, disable maintenance mode, verify, then remove the host
   directories.

## Acceptance

- `docs/operations.md` exists with backup, restore, upgrade, rotation and
  migration sections.
- Backup followed by restore into an empty namespace yields a working
  instance with the same users and files.
- An upgrade across one major version succeeds following the runbook.
