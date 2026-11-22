# ADR 0009: Use the Apache variant of the Nextcloud image

- Status: Proposed
- Date: 2026-11-22

## Context

The official `nextcloud` image comes in two variants. `apache` bundles a web
server and serves HTTP on port 80. `fpm` contains only PHP-FPM and needs a
separate web server container (usually nginx) with a fairly long,
Nextcloud-specific configuration that must be kept in step with upstream.

The current manifest uses the untagged image, which resolves to the Apache
variant, without saying so.

## Decision

Use the `-apache` variant explicitly in the image tag
([ADR 0006](0006-image-pinning.md)).

## Alternatives considered

- **`fpm` + nginx sidecar.** Somewhat better performance under load and
  allows running fully non-root, but adds a container, a ConfigMap with
  roughly 150 lines of nginx configuration, and a second thing to update on
  every Nextcloud major. That contradicts
  [ADR 0001](0001-project-scope.md).
- **Nextcloud AIO.** Designed around the Docker socket; not a fit for
  Kubernetes manifests.

## Consequences

- One container serves the application; no web server configuration lives in
  this repository.
- The container starts as root to bind port 80 and then drops to
  `www-data`, so the Pod cannot satisfy the `restricted` Pod Security
  Standard. The namespace is enforced at `baseline`
  ([spec 001](../specs/001-target-architecture.md)).
- `.htaccess`-based behaviour (pretty URLs, `.well-known` redirects) works
  out of the box.
