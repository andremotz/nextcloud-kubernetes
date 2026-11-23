# ADR 0012: A quickstart overlay with no prerequisites

- Status: Accepted (2026-11-23; implemented on branch `p1-restructure`)
- Date: 2026-11-22
- Amends: [ADR 0002](0002-kustomize-layout.md)

## Context

[ADR 0005](0005-tls-and-ingress.md) moves TLS to an ingress controller and
cert-manager. That is the right design for a real install, but it means a
reader can no longer try the project on a fresh `kind` or `minikube` cluster
without installing two other things first. For a repository whose purpose is
teaching ([ADR 0001](0001-project-scope.md)), the first successful run
should be as short as possible.

## Decision

Ship two overlays instead of one:

| Overlay | Purpose | Needs |
| --- | --- | --- |
| `overlays/local` | Try it out; also used by the CI smoke test | A cluster with a default StorageClass |
| `overlays/example` | Template for a real install | Ingress controller, cert-manager, DNS name |

`overlays/local`:

- No Ingress, no Certificate, no TLS.
- Access through `kubectl port-forward svc/nextcloud 8080:80`.
- `NEXTCLOUD_TRUSTED_DOMAINS=localhost`; no `OVERWRITEPROTOCOL`.
- Small volume sizes.
- Fixed, clearly fake credentials committed in the overlay, with a comment
  that it must never be exposed beyond localhost.

The Ingress therefore moves out of `base/` and into `overlays/example` (or a
shared component), so that `base/` contains only what both overlays need.

## Alternatives considered

- **Only the ingress-based overlay.** Fewer files, slower first run, and CI
  has to install an ingress controller and cert-manager just to test whether
  Nextcloud boots.
- **NodePort instead of port-forward.** No long-running command, but the
  reachable address differs between kind, minikube and k3s, which makes the
  trusted-domain setting unpredictable.

## Consequences

- Quick start in the README shrinks to: create cluster, apply overlay,
  port-forward, open browser.
- CI smoke test needs no extra components; the ingress path is tested
  separately (WI-23).
- Committed test credentials exist in the repo. They are confined to the
  local overlay and secret scanning must be told to ignore that file.
- Two overlays to keep in step.
