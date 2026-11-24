# ADR 0014: Use current Pod features and set a minimum Kubernetes version

- Status: Accepted (2026-11-23). Native sidecar, startup probe, `fsGroupChangePolicy` (MariaDB), seccomp and Pod Security labels are implemented; the optional user-namespace component (WI-40) is not.
- Date: 2026-11-22

## Context

The manifests were written for Kubernetes 1.11. The plan so far (ADR
0002–0012) brings them to roughly the state of the art of 2021. Several
features that became stable later solve problems this design has; see
[Kubernetes changes since 2018](../kubernetes-changes-since-2018.md).
Using them means declaring a minimum cluster version, which
[ADR 0011](0011-versioning-and-support-policy.md) left implicit.

## Decision

**Minimum version.** The manifests target the Kubernetes minor versions
that are supported upstream at release time, and may use any feature that
is GA in the oldest of them. The README states the minimum explicitly.

**Features adopted in the base:**

| Feature | Used for |
| --- | --- |
| Native sidecar container (init container with `restartPolicy: Always`) | The cron container: started before and stopped after the app container |
| Startup probe | Nextcloud's slow first start |
| `fsGroupChangePolicy: OnRootMismatch` | Avoids a recursive ownership change of the whole data volume on every Pod start |
| `seccompProfile: RuntimeDefault` | Set explicitly; clusters do not apply it by default |
| Pod Security Admission namespace labels | Enforce `baseline`, warn and audit on `restricted` |
| `networking.k8s.io/v1` Ingress with `ingressClassName` | Replaces the deprecated annotation |
| CronJob `timeZone` and Job `ttlSecondsAfterFinished` | Backup job runs at a predictable local time and cleans up after itself |

**Features adopted where available, not required:**

| Feature | Used for | Why optional |
| --- | --- | --- |
| User namespaces (`hostUsers: false`) | The Apache image starts as root; with a user namespace that root is unprivileged on the node | Needs runtime, kernel and filesystem support that not every node has |
| CSI `VolumeSnapshot` | Consistent backups | Depends on the storage driver |
| Server-side apply (`kubectl apply --server-side`) | Cleaner field ownership, no annotation size limit | A client-side habit, documented rather than required |

Optional features live in Kustomize components (and commented values on the
Helm path) so the base works without them.

## Alternatives considered

- **Lowest common denominator.** Supports old clusters, but old clusters
  are unsupported upstream anyway, and the design would keep workarounds
  that newer versions make unnecessary.
- **Always require the newest release.** Excludes managed and LTS
  distributions that trail upstream by a few months.

## Consequences

- The cron sidecar becomes a few lines under `initContainers`, and Pod
  shutdown order is correct by construction.
- Users on clusters older than the stated minimum get a clear message
  instead of a confusing failure; CI's version matrix enforces the claim.
- Each time upstream drops a version, the minimum rises and newly GA
  features can be reviewed. That review is a recurring work item (WI-45).
