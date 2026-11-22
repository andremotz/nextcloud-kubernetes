# Spec 003: Ingress and TLS

- Status: Draft
- Date: 2026-11-22
- Implements: ADR 0005

## Prerequisites (not installed by this repo)

- An ingress controller that serves `networking.k8s.io/v1` Ingress.
- cert-manager.
- For Let's Encrypt: a public DNS name pointing at the cluster and port 80
  reachable from the internet.

## Ingress

- One host, set in the overlay.
- One rule: `/` (`Prefix`) → Service `nextcloud`, port 80.
- `tls` block referencing Secret `nextcloud-tls`.
- Annotation `cert-manager.io/cluster-issuer: <issuer>`; the issuer name is
  set in the overlay.
- `ingressClassName` is unset in the base and may be set in the overlay.

## Issuers (overlay)

| File | Issuer | Use |
| --- | --- | --- |
| `issuer-selfsigned.yaml` | `selfSigned` ClusterIssuer | Offline and lab use; replaces omgwtfssl |
| `issuer-letsencrypt.yaml` | ACME HTTP-01, production endpoint | Needs an e-mail address in the overlay |

The example overlay enables the self-signed issuer by default so that the
install works without public DNS; switching is a one-line change.

## Behaviour the proxy layer must provide

These are the things the current `nginx.conf` gets wrong or omits; they are
requirements regardless of which controller is used.

| Requirement | Why |
| --- | --- |
| Request body limit ≥ the PHP upload limit (or unlimited) | nginx defaults to 1 MB, so uploads fail with HTTP 413 |
| Proxy read/send timeout ≥ 3600 s | Large uploads and long-running requests |
| Request buffering off | Avoids spooling multi-GB uploads to the controller's disk |
| `X-Forwarded-Proto`, `X-Forwarded-For`, `Host` forwarded | Nextcloud builds wrong (http) URLs otherwise |
| HTTP → HTTPS redirect | |
| HSTS header (`max-age` ≥ 15552000) | Nextcloud's security check asks for it |
| `/.well-known/carddav` and `/.well-known/caldav` → `/remote.php/dav/` (301) | Client auto-discovery |
| TLS 1.2 minimum | |

How to set the limits per controller is documented as a table in the README
(annotation names differ between Traefik, HAProxy, NGINX-based controllers
and cloud controllers). The exact annotation names must be taken from each
controller's current documentation when the README is written, not from
memory.

The Apache-based Nextcloud image already handles the `.well-known` redirects
through its `.htaccess`; this needs verifying behind the ingress, and only
if it fails is a controller-level redirect added.

## Out of scope

- Installing or configuring the ingress controller.
- DNS-01 challenges and wildcard certificates.
- Gateway API (WI-19).

## Acceptance

- `curl -I http://<hostname>/` returns a redirect to HTTPS.
- `curl -I https://<hostname>/status.php` returns 200 with a certificate
  issued by the configured issuer.
- The certificate Secret is renewed by cert-manager without manual steps.
- Nextcloud's admin overview shows no HSTS or `.well-known` warnings.
