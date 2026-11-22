# Spec 002: Nextcloud runtime configuration

- Status: Draft
- Date: 2026-11-22

## Problem

`nc-deployment.yaml` uses the official `nextcloud` image but sets variables
that this image does not document: `NEXTCLOUD_URL`,
`NEXTCLOUD_UPLOAD_MAX_FILESIZE`, `NEXTCLOUD_MAX_FILE_UPLOADS` and `DEBUG`.
They appear to come from a different community image and are most likely
ignored. The practical effect is that the public hostname is never
registered as a trusted domain and the 4G upload limit is never applied.

Confirmed on 2026-11-22 against the image documentation
(`docker-library/docs`, `nextcloud/README.md`): none of the four variables
appears there. The variable names below are the documented ones, and were
checked in a container run of `nextcloud:34.0.6-apache` (WI-02).

## Environment

| Variable | Source | Purpose |
| --- | --- | --- |
| `MYSQL_HOST` | literal `mariadb` | Database Service |
| `MYSQL_DATABASE`, `MYSQL_USER` | literal `nextcloud` | |
| `MYSQL_PASSWORD` | Secret | |
| `NEXTCLOUD_ADMIN_USER`, `NEXTCLOUD_ADMIN_PASSWORD` | Secret | Enables unattended first install |
| `NEXTCLOUD_TRUSTED_DOMAINS` | overlay (hostname) | Replaces `NEXTCLOUD_URL` |
| `OVERWRITEPROTOCOL` | literal `https` | TLS ends at the ingress |
| `OVERWRITECLIURL` | overlay (`https://<hostname>`) | Correct links from background jobs |
| `TRUSTED_PROXIES` | overlay (Pod CIDR) | So client IPs are taken from `X-Forwarded-For` |
| `PHP_UPLOAD_LIMIT` | overlay, default `4G` | Replaces `NEXTCLOUD_UPLOAD_MAX_FILESIZE` |
| `APACHE_BODY_LIMIT` | literal `"0"` | The image's Apache caps request bodies at 1 GiB by default; the ingress enforces the limit instead |
| `PHP_MEMORY_LIMIT` | overlay, default `512M` | |
| `TZ` | overlay | Was hard-coded to `Europe/Berlin` |

The hostname is defined once in the overlay and reused for the Ingress host,
`NEXTCLOUD_TRUSTED_DOMAINS` and `OVERWRITECLIURL` (Kustomize `replacements`).

## Background jobs

Nextcloud needs `cron.php` every five minutes; the current setup falls back
to AJAX cron, which only runs while someone has the web UI open.

A second container in the Nextcloud Pod runs the same image with
`/cron.sh` as its command and mounts the same volume. A sidecar is chosen
over a `CronJob` because the data volume is `ReadWriteOnce` and a CronJob Pod
could be scheduled on another node.

After the first install, `occ background:cron` must be set once (documented
in the README, or done by a post-install hook script).

## Probes

| Probe | Check | Notes |
| --- | --- | --- |
| startup | `GET /status.php`, up to 10 minutes | First start copies the app into the PVC |
| readiness | `GET /status.php` | |
| liveness | `GET /status.php`, generous timeout | |

Probes send `Host: <hostname>`, otherwise the trusted-domain check rejects
them.

## Caching and file locking (optional, later)

Without Redis, Nextcloud uses database-backed file locking, which is
acceptable for a small instance. An optional overlay may add a single Redis
Pod and `REDIS_HOST`. Tracked as WI-18; not part of the base.

## Acceptance

- A fresh install reaches the dashboard at `https://<hostname>` without the
  "untrusted domain" page.
- Settings → Administration → Overview shows no warning about reverse-proxy
  headers, HTTPS or background jobs.
- A 2 GB file uploads through the web UI.
- The last-cron timestamp advances while no browser session is open.
