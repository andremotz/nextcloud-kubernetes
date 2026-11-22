# Backlog

Written 2026-11-22 against commit `0c6e488`. Priorities:

- **P0**: defects in the manifests as they are today; fixable without any
  architectural decision.
- **P1**: the restructure described in the ADRs and specs.
- **P2**: repository hygiene and documentation.
- **P3**: optional extras.

P0 items stay worthwhile even if the P1 restructure is accepted, because
they are small and the restructure removes some of the affected files only
later. If ADR 0005 is accepted first, WI-01, WI-03 and WI-04 are resolved by
deleting the files instead.

## P0: defects today

### WI-01 Remove the Docker socket mount from the proxy Pod

`kubernetes-yaml/proxy-pod.yaml:29-30,40-43` mounts `/var/run/docker.sock`
into the internet-facing nginx container. Nothing uses it. It gives the
container root-equivalent control of the node, and with `type: Socket` the
Pod cannot start on containerd-based clusters (Kubernetes ≥ 1.24).

- [ ] Volume and volumeMount removed.
- [ ] Pod starts on a containerd cluster.

### WI-02 Use environment variables the official Nextcloud image understands

`kubernetes-yaml/nc-deployment.yaml:23-34` sets `DEBUG`, `NEXTCLOUD_URL`,
`NEXTCLOUD_UPLOAD_MAX_FILESIZE` and `NEXTCLOUD_MAX_FILE_UPLOADS`, which the
official image does not document. See [spec 002](specs/002-nextcloud-runtime.md).

- [ ] Variable list verified against the image's current README.
- [ ] `NEXTCLOUD_TRUSTED_DOMAINS`, `OVERWRITEPROTOCOL`, `PHP_UPLOAD_LIMIT`
      set; unknown variables removed.
- [ ] Fresh install opens without the "untrusted domain" page.

### WI-03 Fix the nginx proxy configuration

`kubernetes-yaml/nginx.conf`:

- No `client_max_body_size`, so nginx rejects uploads above 1 MB with 413
  although the deployment advertises 4G.
- No `X-Forwarded-Proto` header, so Nextcloud does not know the request was
  HTTPS.
- No proxy timeouts, HSTS header, `ssl_protocols` or HTTP/2.
- Line 43 is indented with a tab.

- [ ] Directives added per the table in [spec 003](specs/003-ingress-and-tls.md).
- [ ] 2 GB upload succeeds through the proxy.

### WI-04 Fix the relative mount path in the omgwtfssl Pod

`kubernetes-yaml/omgwtfssl-pod.yaml:26` has `mountPath: certs`; it must be
`/certs` to match the `SSL_*` paths on lines 16-20.

- [ ] Path corrected; certificate files appear in the host directory.

### WI-05 Pin image tags

All four images are untagged (`latest`). See [ADR 0006](adr/0006-image-pinning.md).

- [ ] Every `image:` has an explicit version tag.
- [ ] README states which Nextcloud and MariaDB versions were tested.

### WI-06 Fix the README install instructions that no longer work

- Line 21-22: `apt-key` and the `apt.kubernetes.io` repository are gone;
  packages moved to `pkgs.k8s.io`.
- Line 19: Docker as the container runtime needs `cri-dockerd` since 1.24.
- Line 29: the Flannel manifest moved from `coreos/flannel` to
  `flannel-io/flannel`.
- Line 30: the taint is `node-role.kubernetes.io/control-plane`, not
  `master`.
- Line 12: Ubuntu 18.04 is out of standard support.
- Line 101: two instructions are run together on one line.

Preferred fix is WI-16 (drop the walkthrough); until then:

- [ ] Each command verified on a current LTS release or replaced by a link.
- [ ] Line 101 split.

## P1: restructure

### WI-07 Decide the ADRs

- [ ] ADR 0001–0008 each marked Accepted, Rejected or amended.
- [ ] Ingress vs Gateway API question in ADR 0005 answered.

### WI-08 Tag the current state

- [ ] Tag `v1-legacy` on the last commit before the restructure, so the blog
      post can link to a stable version.

### WI-09 Kustomize base and example overlay (ADR 0002)

- [ ] Layout from [spec 001](specs/001-target-architecture.md) in place.
- [ ] `nextcloud` namespace and `app.kubernetes.io/*` labels.
- [ ] `kubectl apply -k overlays/example` is the only install command.
- [ ] `kubernetes-yaml/` removed.

### WI-10 Secret for credentials (ADR 0003)

- [ ] `secretGenerator` from git-ignored `secrets.env`; example file committed.
- [ ] No password literal in any committed file.

### WI-11 PersistentVolumeClaims (ADR 0004)

- [ ] No `hostPath` anywhere.
- [ ] Data survives Pod deletion on a k3s or kind cluster.

### WI-12 MariaDB StatefulSet (ADR 0007)

- [ ] StatefulSet, headless Service, recommended server flags, probes.

### WI-13 Nextcloud Deployment hardening (specs 001, 002)

- [ ] Probes including startup probe.
- [ ] Resource requests and memory limit.
- [ ] `securityContext` per spec 001.
- [ ] Cron sidecar; background jobs set to Cron.
- [ ] Default-only fields removed.

### WI-14 Ingress and cert-manager (ADR 0005, spec 003)

- [ ] `proxy-pod.yaml`, `nginx.conf`, `omgwtfssl-pod.yaml` removed.
- [ ] Ingress plus self-signed and Let's Encrypt issuers.
- [ ] Acceptance checks from spec 003 pass.

### WI-15 CI (ADR 0008)

- [ ] yamllint, kubeconform, kube-linter, markdownlint.
- [ ] kind smoke test asserting `"installed":true` from `/status.php`.
- [ ] Workflow required on pull requests.

### WI-16 Rewrite the README

- [ ] States scope and links to the official Helm chart (ADR 0001).
- [ ] Prerequisites as links (cluster, StorageClass, ingress controller,
      cert-manager) instead of a cluster-install walkthrough.
- [ ] Quick start in at most five commands.
- [ ] Configuration table for the overlay.
- [ ] Per-controller table for upload size and timeout settings.
- [ ] Warnings: data loss on namespace deletion; Secrets are not encrypted
      at rest by default.
- [ ] Migration note for users of the old layout.
- [ ] "Updates" section replaced by `CHANGELOG.md`.

## P2: hygiene and documentation

### WI-17 Operations runbook (spec 004)

- [ ] `docs/operations.md` with backup, restore, upgrade, rotation, migration.
- [ ] Restore executed once on a test cluster.
- [ ] Optional nightly database-dump CronJob.

### WI-20 NetworkPolicies

- [ ] Default deny in the namespace; allow ingress → nextcloud:80,
      nextcloud → mariadb:3306, DNS, and Nextcloud egress to the internet
      (app store, federation).
- [ ] README notes that enforcement needs a CNI that supports policies
      (Flannel alone does not).

### WI-21 Repository housekeeping

- [ ] `.gitignore` (`secrets.env`, editor and OS files).
- [ ] `.editorconfig` (spaces, LF, final newline) and `.yamllint`.
- [ ] `renovate.json` with Nextcloud majors excluded from auto-merge.
- [ ] `CHANGELOG.md`; releases tagged with semantic versions.
- [ ] `CONTRIBUTING.md` (how to run the checks locally) and `SECURITY.md`.
- [ ] GitHub repository description and topics set.
- [ ] Default branch renamed from `master` to `main` (optional; breaks the
      raw URLs in the old blog post, so add a redirect note there first).

### WI-22 Update or annotate the blog post

- [ ] Post links to the `v1-legacy` tag and carries a note pointing at the
      current README.

## P3: optional

### WI-18 Redis overlay

- [ ] `overlays/with-redis` adding a single Redis Pod and `REDIS_HOST`.

### WI-19 Gateway API overlay

- [ ] `overlays/gateway-api` replacing the Ingress with `Gateway` +
      `HTTPRoute`; cert-manager configured for Gateway API.

### WI-23 Ingress path in the CI smoke test

- [ ] kind cluster with an ingress controller and cert-manager; test hits
      `https://<host>/status.php` through the Ingress.

## Second pass (added later on 2026-11-22)

Items from ADR 0009–0012 and specs 005–006, plus smaller findings. The
priority is given per item.

### WI-24 Decide ADRs 0009–0012 (P1)

- [ ] Each marked Accepted, Rejected or amended.
- [ ] ADR 0002 and ADR 0004 updated to mention the ADRs that amend them.

### WI-25 Local quickstart overlay (P1, ADR 0012)

- [ ] `overlays/local` works on a fresh kind cluster with nothing else
      installed.
- [ ] Ingress moved out of `base/`.
- [ ] CI smoke test (WI-15) uses this overlay.

### WI-26 Separate data volume (P1, ADR 0010)

- [ ] `nextcloud-app` and `nextcloud-data` claims; cron sidecar mounts both.
- [ ] Spec 004 backup, restore and migration steps updated for two volumes.

### WI-27 Makefile, kind config and smoke-test script (P1, spec 005)

- [ ] Targets from spec 005 exist; CI calls them.
- [ ] `hack/smoke-test.sh` covers login, upload, Pod deletion and re-read.
- [ ] Failure output includes events and container logs.

### WI-28 Upgrade test in CI (P2, spec 005)

- [ ] Job deploys the latest release, then the pull request's version, and
      verifies that data survives.
- [ ] Runs on pull requests that change an image tag.

### WI-29 Harden the CI workflow (P1, spec 006)

Do this in the same pull request that introduces CI, not afterwards.

- [ ] Actions pinned by commit SHA.
- [ ] `permissions: contents: read` by default.
- [ ] Renovate configured to update action SHAs.

### WI-30 Security scanning (P2, spec 006)

- [ ] `trivy config` (or kubescape) on rendered overlays, failing on high
      and critical.
- [ ] `gitleaks` with the local overlay's fake credentials allow-listed.
- [ ] Weekly image scan that opens an issue.
- [ ] Branch protection, secret scanning, push protection and private
      vulnerability reporting enabled in the repository settings.

### WI-31 Post-install configuration (P2)

A fresh install shows several warnings in the admin overview that the
manifests can prevent.

- [ ] ConfigMap with a `zz-custom.config.php` snippet mounted into
      `config/`: `default_phone_region`, `maintenance_window_start`,
      `default_timezone`.
- [ ] Optional mail settings through the image's `SMTP_*` and `MAIL_*`
      variables, password from the Secret; left unset by default.
- [ ] README lists the one-off `occ` commands that remain
      (`background:cron`, `db:add-missing-indices`).
- [ ] Admin overview on a fresh install shows no warnings other than ones
      that need real infrastructure (e-mail, public HTTPS).

### WI-32 Graceful shutdown (P2)

- [ ] `terminationGracePeriodSeconds` on MariaDB raised (suggested 60) so
      InnoDB can flush on node drain.
- [ ] Verified by draining the node in the kind cluster with no crash
      recovery in the MariaDB log afterwards.

### WI-33 README content beyond the rewrite in WI-16 (P2)

- [ ] Architecture diagram (Mermaid, renders on GitHub).
- [ ] Tested-versions table (ADR 0011).
- [ ] Troubleshooting section: untrusted domain, 413 on upload, Pod stuck
      in `Pending` (no StorageClass), certificate not issued, login loop
      behind a proxy.
- [ ] Uninstall section, including what happens to the data.
- [ ] "Before you expose this to the internet" checklist (spec 006).
- [ ] Typos and tone tidied ("mail-adress", "set-up", stray placeholder
      syntax); one consistent placeholder style.
- [ ] Status badges for CI and latest release.

### WI-34 Issue and pull request templates (P3)

- [ ] Bug report template asking for Kubernetes version, distribution,
      overlay used and `kubectl get pods,pvc,ingress -n nextcloud` output.
- [ ] Pull request template with a "ran `make test`" checkbox.

### WI-35 Licence clarity (P3, maintainer's decision)

The repository is GPL-3.0. For configuration that people copy into private
repositories, a permissive licence (MIT or Apache-2.0) is more common and
removes doubt about whether an adapted copy must be published. All 18
commits are by the maintainer, so relicensing needs nobody else's consent.

- [ ] Decision recorded (keep GPL-3.0 or relicense).
- [ ] README states the licence in one line either way.

### WI-36 Pointers for things that are out of scope (P3)

So that ADR 0001's "not in this repo" does not leave readers stranded:

- [ ] README section "Going further" linking to the official Helm chart,
      Redis, object storage, metrics exporter, and GitOps secret tooling
      (Sealed Secrets, SOPS, External Secrets).

## Third pass: Helm and Kubernetes modernisation

Items from ADR 0013–0014, spec 007 and
[Kubernetes changes since 2018](kubernetes-changes-since-2018.md).

### WI-37 Evaluate the official Helm chart and decide ADR 0013 and 0014 (P1)

This is research, and it comes before any Helm work.

- [ ] Current chart version, release cadence and open-issue situation noted.
- [ ] How the chart provides MariaDB and Redis today (Bitnami subcharts or
      something else) established; spec 007 database option A or B chosen.
- [ ] Each row of the spec 007 parity table checked against the chart's
      `values.yaml`.
- [ ] ADR 0013 and ADR 0014 marked Accepted, Rejected or amended.

### WI-46 Helm path (P1, spec 007)

- [ ] `helm/values.yaml`, `helm/values-local.yaml`, `helm/CHART_VERSION`,
      `helm/README.md`.
- [ ] `make validate` and `make smoke` cover the Helm path.
- [ ] Renovate tracks the chart version.
- [ ] README has the "which path" table.

### WI-38 Cron as a native sidecar (P1, ADR 0014)

- [ ] Cron container moved to `initContainers` with `restartPolicy: Always`.
- [ ] Minimum Kubernetes version stated in the README.

### WI-39 `fsGroupChangePolicy: OnRootMismatch` (P2, ADR 0014)

- [ ] Set on the Nextcloud and MariaDB Pods where `fsGroup` is used.
- [ ] Pod restart time with a populated data volume measured before and
      after.

### WI-40 User-namespace component (P2, ADR 0014)

- [ ] Kustomize component setting `hostUsers: false` on the Nextcloud Pod.
- [ ] Current stability level of the feature and its node requirements
      checked and documented.
- [ ] Tested on a cluster that supports it; confirmed that the base still
      works on one that does not.

### WI-41 Document volume expansion (P2)

- [ ] Runbook section: how to grow `nextcloud-data` and the MariaDB claim,
      and the note that the StorageClass needs `allowVolumeExpansion`.

### WI-42 Recommend server-side apply (P3)

- [ ] README uses `kubectl apply --server-side -k ...`.
- [ ] Verified that re-applying after a manual `kubectl scale` behaves as
      documented.

### WI-43 Dual-stack and IPv6 check (P3)

- [ ] No manifest or default assumes IPv4.
- [ ] `TRUSTED_PROXIES` guidance covers IPv6 Pod ranges.

### WI-44 GitOps examples (P3)

- [ ] `examples/argocd/application.yaml` and `examples/flux/` for both the
      Kustomize overlay and the Helm values.
- [ ] README note on where the Secret comes from in a GitOps setup
      (it cannot come from the git-ignored `secrets.env`).

### WI-45 Recurring: review when upstream drops a Kubernetes version (P3)

- [ ] CI version matrix updated.
- [ ] Minimum version in the README raised.
- [ ] Features that became GA reviewed against ADR 0014's "optional" table.
- [ ] `kubernetes-changes-since-2018.md` extended if something affects the
      design.

## Suggested order

Supersedes the order implied by the sections above.

1. WI-07, WI-24 and WI-37 (decisions and chart evaluation), WI-08 (tag).
2. WI-01, WI-04, WI-05, WI-02, WI-03, WI-06: one small PR each, or skip the
   ones that WI-14 deletes.
3. WI-09 → WI-25 → WI-27 → WI-15 + WI-29. From here on every step is tested
   by `make test` and CI.
4. WI-10 → WI-11 + WI-26 → WI-12 → WI-13 + WI-38 → WI-14.
5. WI-46 (Helm path), once the manifests path passes the smoke test and
   defines what parity means.
6. WI-16 + WI-33, WI-17, first tagged release (ADR 0011).
7. Remaining P2 and P3 items as wanted.
