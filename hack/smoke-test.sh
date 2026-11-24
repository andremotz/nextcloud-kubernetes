#!/usr/bin/env bash
# Smoke test against the cluster in the current kube context.
# See docs/specs/005-local-development-and-testing.md.
#
# Environment:
#   NAMESPACE     namespace of the install       (default: nextcloud)
#   SERVICE       Nextcloud Service name         (default: nextcloud)
#   DEPLOYMENT    Nextcloud Deployment name      (default: nextcloud)
#   DB_WORKLOAD   database workload              (default: statefulset/mariadb)
#   ADMIN_USER / ADMIN_PASSWORD                  (default: local overlay values)
#   LOCAL_PORT    port for kubectl port-forward  (default: 18080)
#   SERVICE_PORT  port of the Nextcloud Service  (default: 80)
set -Eeuo pipefail

NAMESPACE=${NAMESPACE:-nextcloud}
SERVICE=${SERVICE:-nextcloud}
DEPLOYMENT=${DEPLOYMENT:-nextcloud}
DB_WORKLOAD=${DB_WORKLOAD:-statefulset/mariadb}
ADMIN_USER=${ADMIN_USER:-admin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-local-admin-password}
LOCAL_PORT=${LOCAL_PORT:-18080}
SERVICE_PORT=${SERVICE_PORT:-80}

k() { kubectl -n "$NAMESPACE" "$@"; }
step() { printf '\n==> %s\n' "$*"; }
occ() { k exec "deploy/$DEPLOYMENT" -c nextcloud -- su -s /bin/sh www-data -c "php occ $*"; }

pf_pid=""
tmp=$(mktemp -d)
cleanup() {
  [ -n "$pf_pid" ] && kill "$pf_pid" 2>/dev/null || true
  rm -rf "$tmp"
}
diagnose() {
  echo "!! smoke test failed; cluster state follows" >&2
  k get all,pvc >&2 || true
  k get events --sort-by=.lastTimestamp 2>/dev/null | tail -20 >&2 || true
  for pod in $(k get pods -o name 2>/dev/null); do
    for c in $(k get "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}'); do
      echo "--- $pod / $c" >&2
      k logs "$pod" -c "$c" --tail=100 >&2 || true
    done
  done
}
trap cleanup EXIT
trap diagnose ERR

port_forward() {
  [ -n "$pf_pid" ] && kill "$pf_pid" 2>/dev/null || true
  k port-forward "svc/$SERVICE" "$LOCAL_PORT:$SERVICE_PORT" >/dev/null 2>&1 &
  pf_pid=$!
  disown "$pf_pid" 2>/dev/null || true
  for _ in $(seq 1 30); do
    curl -fsS "http://localhost:$LOCAL_PORT/status.php" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "port-forward did not become ready" >&2
  return 1
}
dav() { curl -fsS -u "$ADMIN_USER:$ADMIN_PASSWORD" "$@"; }
url="http://localhost:$LOCAL_PORT"

step "Waiting for $DB_WORKLOAD and deployment/$DEPLOYMENT"
k rollout status "$DB_WORKLOAD" --timeout=600s
k rollout status "deploy/$DEPLOYMENT" --timeout=600s

step "status.php reports installed and not in maintenance"
port_forward
status=$(curl -fsS "$url/status.php")
echo "$status"
grep -q '"installed":true' <<<"$status"
grep -q '"maintenance":false' <<<"$status"

step "WebDAV login (PROPFIND)"
code=$(dav -o /dev/null -w '%{http_code}' -X PROPFIND -H 'Depth: 0' "$url/remote.php/dav/files/$ADMIN_USER/")
[ "$code" = 207 ] || { echo "expected 207, got $code" >&2; false; }

step "Upload a 20 MB file and read it back"
head -c 20000000 /dev/urandom >"$tmp/upload.bin"
want=$(shasum -a 256 "$tmp/upload.bin" | cut -d' ' -f1)
dav -T "$tmp/upload.bin" "$url/remote.php/dav/files/$ADMIN_USER/smoke-test.bin" -o /dev/null
got=$(dav "$url/remote.php/dav/files/$ADMIN_USER/smoke-test.bin" | shasum -a 256 | cut -d' ' -f1)
[ "$want" = "$got" ] || { echo "checksum mismatch after upload" >&2; false; }

step "Background jobs are set to cron"
mode=$(occ config:app:get core backgroundjobs_mode)
[ "$mode" = cron ] || { echo "expected backgroundjobs_mode=cron, got '$mode'" >&2; false; }

step "Delete the Nextcloud Pod; data must survive"
k delete pod -l app.kubernetes.io/name=nextcloud --wait=true
k rollout status "deploy/$DEPLOYMENT" --timeout=600s
port_forward
got=$(dav "$url/remote.php/dav/files/$ADMIN_USER/smoke-test.bin" | shasum -a 256 | cut -d' ' -f1)
[ "$want" = "$got" ] || { echo "file lost or changed after Pod restart" >&2; false; }

step "occ status and occ check"
occ status
occ check

step "Cleanup"
dav -X DELETE "$url/remote.php/dav/files/$ADMIN_USER/smoke-test.bin" -o /dev/null

printf '\nSmoke test passed.\n'
