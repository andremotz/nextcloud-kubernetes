# ADR 0005: Ingress + cert-manager replace the proxy Pod and omgwtfssl

- Status: Accepted (2026-11-23). Ingress is the default; Gateway API stays a later overlay (WI-19).
- Date: 2026-11-22

## Context

HTTPS is currently provided by two bare Pods:

- `proxy`: an `nginx` Pod with `hostPort` 80/443 and a hand-written
  `nginx.conf` mounted from the host.
- `omgwtfssl`: a one-shot Pod that writes a self-signed certificate to a
  host directory.

Problems:

- Bare Pods are not recreated when the node is drained or the Pod is evicted.
- The proxy Pod mounts `/var/run/docker.sock`. Nothing uses it, it hands
  root-equivalent control of the node to an internet-facing container, and
  with `type: Socket` the Pod cannot start at all on containerd-based
  clusters, which is every cluster since Kubernetes 1.24.
- `paulczar/omgwtfssl` is unmaintained, and a self-signed certificate breaks
  the Nextcloud desktop and mobile clients unless users import a CA.
- The certificate never renews.
- `nginx.conf` has functional gaps (see [backlog](../backlog.md) WI-03).

## Decision

- Remove `proxy-pod.yaml`, `nginx.conf` and `omgwtfssl-pod.yaml`.
- Expose Nextcloud through a standard `networking.k8s.io/v1` **Ingress**
  with no controller-specific `ingressClassName` in the base.
- Obtain certificates with **cert-manager**. The overlay ships two issuers:
  a self-signed `ClusterIssuer` (works offline, replaces omgwtfssl) and a
  Let's Encrypt `ClusterIssuer` (HTTP-01).
- The ingress controller and cert-manager are **prerequisites**, not part of
  this repository.

## Alternatives considered

- **Gateway API (`Gateway` + `HTTPRoute`).** The direction the ecosystem is
  moving in, and the community `ingress-nginx` controller was retired in
  March 2026. However the Ingress *API* is still GA and is what k3s (Traefik)
  and most homelab setups serve out of the box. Proposed as an additional
  overlay later (WI-19) rather than the default.
- **Keep nginx, convert it to a Deployment with a ConfigMap and a TLS
  Secret.** Smallest diff and no prerequisites, but the repo keeps
  maintaining a reverse-proxy configuration and has no certificate renewal.
- **Controller-specific setup (e.g. Traefik `IngressRoute`).** Ties the
  reference to one controller.

## Consequences

- Three files and all controller-specific proxy configuration leave the repo.
- Upload size and timeouts are now set through controller-specific
  annotations; [spec 003](../specs/003-ingress-and-tls.md) lists them for the
  common controllers.
- Two prerequisites are added. On k3s only cert-manager needs installing.
- Nextcloud must be told it sits behind a TLS-terminating proxy
  ([spec 002](../specs/002-nextcloud-runtime.md)).

## Open question

Whether the default should be Ingress or Gateway API is a judgement call for
the maintainer; this ADR recommends Ingress for reach and simplicity.
