# Spec 001: Target architecture and repository layout

- Status: Draft
- Date: 2026-11-22
- Depends on: ADR 0001–0008

## Goal

One command (`kubectl apply -k overlays/example`) brings up a working,
TLS-terminated Nextcloud with MariaDB on any conformant cluster that has a
default StorageClass, an ingress controller and cert-manager.

## Non-goals

High availability, more than one Nextcloud replica, object storage, office
suites, monitoring stack, cluster installation.

## Components

| Resource | Kind | Notes |
| --- | --- | --- |
| `nextcloud` | Namespace | Labelled `pod-security.kubernetes.io/enforce: baseline` |
| `nextcloud-credentials` | Secret | Generated, see ADR 0003 |
| `mariadb` | StatefulSet (1 replica) | ADR 0007 |
| `mariadb` | Service (headless, 3306) | |
| `nextcloud` | Deployment (1 replica, `Recreate`) | App container + cron sidecar, spec 002 |
| `nextcloud-data` | PersistentVolumeClaim (RWO) | Mounted at `/var/www/html` |
| `nextcloud` | Service (ClusterIP, 80) | |
| `nextcloud` | Ingress | Spec 003 |
| `nextcloud-tls` | Certificate → Secret | Issued by cert-manager |
| `default-deny`, `allow-*` | NetworkPolicy | Only ingress → nextcloud:80 and nextcloud → mariadb:3306 |

Request path:

```
client ──HTTPS──▶ ingress controller ──HTTP──▶ Service nextcloud ──▶ Pod nextcloud
                                                                       │
                                                                       ▼
                                                    Service mariadb ──▶ Pod mariadb-0
```

## Repository layout

```
README.md
LICENSE
CHANGELOG.md
.gitignore                    # secrets.env, editor files
.github/workflows/ci.yaml
renovate.json
base/
  kustomization.yaml
  namespace.yaml
  networkpolicy.yaml
  mariadb/
    statefulset.yaml
    service.yaml
  nextcloud/
    deployment.yaml
    pvc.yaml
    service.yaml
    ingress.yaml
overlays/
  example/
    kustomization.yaml        # hostname, sizes, image tags, issuer
    secrets.env.example
    issuer-selfsigned.yaml
    issuer-letsencrypt.yaml
docs/
```

## Requirements for every workload

- Labels: `app.kubernetes.io/name`, `app.kubernetes.io/component`,
  `app.kubernetes.io/part-of: nextcloud`.
- Pinned image tag (ADR 0006).
- `resources.requests` for CPU and memory, `resources.limits.memory`.
- Readiness and liveness probes; a startup probe on Nextcloud, because the
  first start copies the application into the volume and can take minutes.
- `securityContext`: `allowPrivilegeEscalation: false`,
  `seccompProfile: RuntimeDefault`, capabilities dropped to what the image
  needs. MariaDB runs as non-root. The Apache-based Nextcloud image starts as
  root to bind port 80 and drops to `www-data`; that is accepted and
  documented rather than worked around.
- No `hostPath`, `hostPort`, `hostNetwork` or host sockets.
- `automountServiceAccountToken: false`.
- No fields that merely restate defaults (`restartPolicy: Always`,
  `terminationMessagePath`, `protocol: TCP`).

## Suggested starting values (to be confirmed by testing)

| Workload | CPU request | Memory request | Memory limit |
| --- | --- | --- | --- |
| nextcloud | 250m | 512Mi | 1Gi |
| nextcloud cron sidecar | 50m | 128Mi | 512Mi |
| mariadb | 100m | 256Mi | 512Mi |

## Acceptance

- `kubectl kustomize overlays/example | kubeconform -strict` passes.
- The CI smoke test from ADR 0008 passes.
- Deleting the `nextcloud` and `mariadb-0` Pods loses no data.
- The namespace admits all Pods under the `baseline` Pod Security Standard.
