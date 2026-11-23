# Helm path

Installs Nextcloud with the **official chart** ([nextcloud/helm](https://github.com/nextcloud/helm)), in the version given in [`CHART_VERSION`](CHART_VERSION), using the values in this folder. The result has the same architecture as the manifests in `base/` and `overlays/` (see [ADR 0013](../docs/adr/0013-helm-support.md) and [spec 007](../docs/specs/007-helm-path.md)).

MariaDB does not come from the chart. The chart's bundled databases are Bitnami subcharts, so MariaDB is applied from this repository's `base/mariadb` and the chart connects to it as an external database.

## Local (port-forward, no TLS)

```sh
kubectl apply --server-side -k helm/database-local
kubectl -n nextcloud rollout status statefulset/mariadb
helm upgrade --install nextcloud nextcloud --repo https://nextcloud.github.io/helm/ \
  --version "$(cat helm/CHART_VERSION)" -n nextcloud -f helm/values-local.yaml --wait --timeout 15m
kubectl -n nextcloud port-forward svc/nextcloud 8080:8080
```

Open <http://localhost:8080> and log in as `admin` / `local-admin-password`. These are fake, committed credentials.

## Real install

Prerequisites are the same as for the manifests path: a default StorageClass, an ingress controller and cert-manager.

1. Copy `helm/database-example/secrets.env.example` to `secrets.env` in the same folder. That file is git-ignored. Fill in every value.
2. In `helm/values.yaml`, replace every `cloud.example.com` and set `TRUSTED_PROXIES` to your pod network.
3. Apply a certificate issuer, for example `kubectl apply -f overlays/example/issuer-selfsigned.yaml`, or `overlays/example/issuer-letsencrypt.yaml` after setting its e-mail address; then set the issuer name in `ingress.annotations`.
4. Apply the controller settings from "Ingress controller settings" in the main README. For Traefik, apply `components/traefik/middlewares.yaml` and add the `traefik.ingress.kubernetes.io/router.middlewares` annotation from `components/traefik/kustomization.yaml` to `ingress.annotations`.
5. Install:

   ```sh
   kubectl apply --server-side -k helm/database-example
   kubectl -n nextcloud rollout status statefulset/mariadb
   helm upgrade --install nextcloud nextcloud --repo https://nextcloud.github.io/helm/ \
     --version "$(cat helm/CHART_VERSION)" -n nextcloud -f helm/values.yaml --wait --timeout 15m
   ```

## Upgrading

- **Nextcloud:** change `image.tag` in both values files, together with the tag in `base/nextcloud/kustomization.yaml`. `make validate` fails if the two paths disagree.
- **Chart:** change `CHART_VERSION`, then run `make validate` and `make test-helm`. Read the chart's changelog first.
- The one-major-at-a-time rule and the backup advice from the main README apply.

## Differences from the manifests path

| | Manifests path | Helm path |
| --- | --- | --- |
| Cron sidecar | Native sidecar (init container with `restartPolicy: Always`) | Regular second container |
| Resource names | `nextcloud-app`, `nextcloud-data` PVCs | `nextcloud-nextcloud`, `nextcloud-nextcloud-data` PVCs |
| Service port | 80 | 8080 |
| Probes | `Host: localhost` | `Host: <nextcloud.host>` |
| Settings | `settings.env` (one place) | Hostname appears several times in `values.yaml` |

Moving an existing install between the two paths means a backup and restore, not an in-place switch.
