# Kubernetes changes since 2018 and what they mean for this repo

Written 2026-11-22. The manifests date from July 2018 (Kubernetes 1.11) with
one API-version fix in December 2019. This page lists what changed in the
ecosystem since then, whether the repo is affected, and where the plan deals
with it.

Version numbers and dates below were written from memory. They are accurate
enough for planning; check the Kubernetes release notes before quoting any
of them in the README.

## Things that break the current manifests or README

| Change | When | Effect here | Handled in |
| --- | --- | --- | --- |
| Dockershim removed; containerd is the default runtime | 1.24 (2022) | `/var/run/docker.sock` does not exist, so the proxy Pod cannot start. `apt install docker.io` no longer gives a usable runtime on its own | WI-01, WI-06 |
| Package repositories moved to `pkgs.k8s.io`; the old `apt.kubernetes.io` was frozen and then removed | 2023–2024 | README install commands fail | WI-06, WI-16 |
| Control-plane taint and label renamed from `master` to `control-plane` | 1.20–1.25 | `kubectl taint ... master-` in the README does nothing | WI-06 |
| Flannel moved from `coreos/flannel` to `flannel-io/flannel` | 2021 | Manifest URL in the README is stale | WI-06 |
| `apt-key` deprecated and removed from current Debian and Ubuntu | 2020 onward | README install command fails | WI-06 |
| Docker Hub pull rate limits | 2020 | Untagged images are re-pulled often; pulls can fail on shared IPs | ADR 0006 |

## Things that make the current design obsolete

| Change | When | Effect here | Handled in |
| --- | --- | --- | --- |
| Ingress API became GA (`networking.k8s.io/v1`), with `IngressClass` | 1.19 (2020) | A hand-rolled nginx Pod with `hostPort` is no longer the normal way to expose HTTP | ADR 0005 |
| Gateway API reached GA | 2023 | Successor to Ingress for new designs | ADR 0005 (open question), WI-19 |
| Community `ingress-nginx` controller retired | March 2026 | Do not assume or recommend that controller | ADR 0005, spec 003 |
| cert-manager became the standard way to obtain certificates | 2019 onward | One-shot self-signed certificate Pods are obsolete | ADR 0005 |
| PodSecurityPolicy removed; Pod Security Admission built in | 1.25 (2022) | `hostPath`, `hostPort` and host sockets are rejected in namespaces enforcing `baseline` | ADR 0004, ADR 0014, spec 001 |
| CSI and dynamic provisioning became universal; small distributions ship a default StorageClass | 2019 onward | `hostPath` is no longer needed even on one node | ADR 0004 |
| Kustomize built into `kubectl` | 1.14 (2019) | Hand-editing downloaded files is unnecessary | ADR 0002 |
| Helm 3 (no Tiller), OCI chart distribution, Helm 4 | 2019, 2022, 2025 | Helm became the default packaging; an official Nextcloud chart exists | ADR 0013, spec 007 |
| kind, k3s, minikube and similar | 2019 onward | A kubeadm walkthrough is no longer the easiest way to get a test cluster | ADR 0012, WI-16 |

## Newer features worth adopting

| Feature | Stable since | Use here | Handled in |
| --- | --- | --- | --- |
| Startup probes | 1.20 | Nextcloud's slow first start | Spec 001, ADR 0014 |
| Native sidecar containers | 1.33 | Cron container with correct start and stop order | ADR 0014, WI-38 |
| `fsGroupChangePolicy` | 1.23 | Faster Pod start with large data volumes | ADR 0014, WI-39 |
| User namespaces for Pods | Enabled by default from 1.33; check current status | Makes the root-starting Apache image much less risky | ADR 0014, WI-40 |
| Volume snapshots | 1.20 | Consistent backups | Spec 004 |
| Volume expansion | 1.24 | Growing the data volume without migration | WI-41 |
| CronJob `batch/v1`, `timeZone` field | 1.21, 1.27 | Backup job | ADR 0014, WI-17 |
| Job `ttlSecondsAfterFinished` | 1.23 | Finished backup Jobs clean themselves up | ADR 0014 |
| Server-side apply | 1.22 | Recommended apply mode in the README | ADR 0014, WI-42 |
| Ephemeral containers (`kubectl debug`) | 1.25 | Troubleshooting section of the README | WI-33 |
| Immutable Secrets and ConfigMaps | 1.21 | Pairs well with Kustomize's hashed names | Optional, WI-10 |
| Dual-stack networking | 1.23 | Nothing may assume IPv4; `TRUSTED_PROXIES` needs both ranges on dual-stack clusters | WI-43 |
| Recommended `app.kubernetes.io/*` labels | Convention | Tooling and dashboards expect them | ADR 0002 |

## Changes in how people run clusters

| Change | Effect here | Handled in |
| --- | --- | --- |
| GitOps with Argo CD or Flux is common | A Kustomize overlay and a Helm values file are both directly consumable; an example `Application` / `Kustomization` costs little | WI-44 |
| Operators manage databases (mariadb-operator, CloudNativePG) | The plain StatefulSet stays the default for readability; operators are named as the next step | ADR 0007, WI-36 |
| arm64 nodes are common in homelabs | `nextcloud` and `mariadb` images are multi-arch; the old `omgwtfssl` image is another reason to drop it. State arm64 as "expected to work, not tested in CI" | WI-33 |
| Swap no longer has to be disabled on recent versions | The README's "Final hint" about `/etc/fstab` is outdated advice; it disappears with the install walkthrough | WI-16 |
| Bitnami restricted its free images and charts in 2025 | Affects charts that depend on Bitnami subcharts, possibly including the official Nextcloud chart's bundled database | ADR 0013 ("To verify") |
| Secrets encryption at rest with KMS v2 | Still off by default on self-built clusters; the README should say so | ADR 0003 |

## Changes on the Nextcloud side

| Change | Effect here | Handled in |
| --- | --- | --- |
| The official image's environment variables | Four variables in `nc-deployment.yaml` are not recognised | WI-02, spec 002 |
| One-major-at-a-time upgrade rule, three releases a year | Unpinned image is dangerous | ADR 0006, spec 004 |
| Nextcloud All-in-One exists | It is Docker-socket based and not a Kubernetes design; mention it as the alternative for single Docker hosts | WI-36 |
| `notify_push`, Redis, object storage, office suites | Optional components, out of scope; linked from "Going further" | ADR 0001, WI-18, WI-36 |
| Admin overview checks became stricter | Fresh installs show warnings unless configured | WI-31 |

## Summary

Nothing in the current repository is unaffected. In order of importance:

1. The README's cluster setup and the proxy Pod do not work at all on a
   current cluster.
2. The exposure, storage and secret handling follow patterns that Kubernetes
   has since replaced with built-in mechanisms.
3. A handful of newer Pod features remove workarounds the first plan still
   contained (the plain cron sidecar, running as root without mitigation).
