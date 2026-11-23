# ADR 0004: PersistentVolumeClaims instead of hostPath

- Status: Accepted (2026-11-23; implemented on branch `p1-restructure`)
- Date: 2026-11-22
- Amended by: [ADR 0010](0010-separate-data-volume.md) (user data on its own claim)

## Context

All state (MariaDB data, the Nextcloud `html` tree, certificates, nginx logs
and even `nginx.conf`) is mounted with `hostPath` from a directory under
`/home/<someFolderLocation>`.

Problems:

- The Pods are silently tied to one node; on a multi-node cluster a
  rescheduled Pod starts with an empty directory.
- `hostPath` is blocked by the `baseline` Pod Security Standard.
- No size, no access mode, no way to snapshot or move the data with standard
  tooling.
- Configuration (`nginx.conf`) is delivered through the node's filesystem
  instead of through the API.

## Decision

- MariaDB data and Nextcloud data use PersistentVolumeClaims that request
  storage from the cluster's **default StorageClass**. No StorageClass name is
  hard-coded in the base.
- Sizes are set in the overlay (suggested defaults: 5Gi database, 20Gi
  Nextcloud).
- Access mode is `ReadWriteOnce`; the design stays single-replica.
- The README names `local-path-provisioner` (bundled with k3s) as the
  simplest option for single-node clusters.
- Configuration files, if any remain, come from ConfigMaps.

## Alternatives considered

- **Static `local` PersistentVolumes with node affinity.** Explicit and
  provisioner-free, but the user must still create directories on the node
  and edit node names.
- **Keep `hostPath`, document the limits.** Zero effort; keeps every problem
  above.
- **NFS / `ReadWriteMany`.** Would allow more than one Nextcloud replica, but
  that is out of scope ([ADR 0001](0001-project-scope.md)).

## Consequences

- Works unchanged on k3s, kind, minikube and managed clusters.
- Bare kubeadm clusters have no default StorageClass; the README must state
  this prerequisite.
- Existing users need a one-off data migration from the host directories;
  see [spec 004](../specs/004-operations.md).
- Deleting the namespace deletes the PVCs and, with the usual `Delete`
  reclaim policy, the data. The README must warn about this.
