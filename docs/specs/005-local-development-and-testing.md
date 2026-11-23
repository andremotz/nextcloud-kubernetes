# Spec 005: Local development and testing

- Status: Draft
- Date: 2026-11-22
- Implements: ADR 0008, ADR 0012

## Goal

A contributor can run every check CI runs with one command, on a laptop,
without reading the workflow file. CI calls the same entry points, so
"works locally" and "passes CI" mean the same thing.

## Entry points

A `Makefile` at the repository root (plain `make`; no extra task runner):

| Target | Does |
| --- | --- |
| `make lint` | yamllint, markdownlint, link check |
| `make validate` | Renders every overlay and runs kubeconform and kube-linter on the output |
| `make cluster` | Creates a kind cluster named `nextcloud-dev` |
| `make deploy` | Applies `overlays/local` and waits for both rollouts |
| `make smoke` | Runs `hack/smoke-test.sh` against the running cluster |
| `make test` | `lint` + `validate` + `cluster` + `deploy` + `smoke` |
| `make clean` | Deletes the kind cluster |

Tool versions are pinned in one place (a `.tool-versions` file or variables
at the top of the Makefile) and CI reads the same values.

## Smoke test (`hack/smoke-test.sh`)

Runs against whatever cluster the current kube context points at. Steps:

1. Wait for `statefulset/mariadb` and `deployment/nextcloud` to be ready
   (timeout 10 minutes; the first start is slow).
2. Port-forward the Service and fetch `/status.php`; assert
   `"installed":true` and `"maintenance":false`.
3. Log in through the API with the test admin credentials (WebDAV `PROPFIND`
   on the user's root); assert HTTP 207.
4. Upload a file larger than 10 MB over WebDAV and read it back; assert the
   checksum matches.
5. Delete the Nextcloud Pod, wait for the replacement, repeat step 2 and
   re-read the file from step 4. This proves persistence.
6. Run `occ status` and `occ check` in the Pod; assert exit code 0.

On failure the script prints `kubectl get all`, recent events and the last
100 log lines of each container, because that is what a person would ask for
first.

## Upgrade test

A second CI job, run on pull requests that change an image tag:

1. Deploy `overlays/local` from the latest release tag.
2. Upload a file.
3. Apply `overlays/local` from the pull request.
4. Run the smoke test and re-read the file.

This is the test that makes automated image bumps
([ADR 0006](../adr/0006-image-pinning.md)) trustworthy.

## Out of scope

- Load or performance testing.
- Testing against managed cloud clusters.

## Acceptance

- `make test` passes on a clean checkout with only Docker, `kind`,
  `kubectl` and the pinned linters installed.
- The CI workflow contains no logic that is not reachable through a `make`
  target.
- Breaking the Deployment on purpose (for example a wrong database host)
  makes `make smoke` fail with useful output.
