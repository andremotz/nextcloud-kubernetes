# Nextcloud on Kubernetes
nextcloud for kubernetes

For more background information check out my blog-post at https://www.andremotz.com/nextcloud-docker-on-kubernetes-cluster-ssl-certificates/ 

These YAMLs can be used on a Kubernetes-cluster to set-up a Nextcloud using MariaDB and Nginx as a SSL/TLS-Proxy. The YAMLs were originally tested on Ubuntu 18.04 in 2018; the current versions have not yet been tested on a cluster (see `docs/backlog.md`).

## Updates:
* 2026-11-22: Pinned image versions, see "Image versions" below
* 2026-11-22: Nextcloud now uses the environment variables of the official image (`NEXTCLOUD_TRUSTED_DOMAINS`, `OVERWRITEPROTOCOL`, `PHP_UPLOAD_LIMIT` and others). The old `NEXTCLOUD_URL` and `NEXTCLOUD_UPLOAD_MAX_FILESIZE` were ignored by the image. The image applies trusted domains during installation only, so existing installs should check `trusted_domains`, `overwriteprotocol` and `trusted_proxies` in `config/config.php` and add them by hand if they are missing.
* 2026-11-22: `nginx.conf` now allows uploads up to 4G, forwards `X-Forwarded-Proto`, sets HSTS and the CalDAV/CardDAV redirects; `proxy-pod.yaml` no longer mounts the Docker socket (it prevented the Pod from starting on current clusters). If you run an older copy, merge these changes into your edited files on the host.
* 2026-11-22: Self-signed certificates are now valid for 365 days instead of the image default of 60.
* 2019-12-02: Updated Deployments: added selector/matchLabels, changed apiVersion: apps/v1

## Image versions
All images are pinned to explicit versions instead of `latest`:

| Image | Version | Note |
| --- | --- | --- |
| `nextcloud` | `34.0.6-apache` | Current `stable` release line |
| `mariadb` | `11.8.9` | Recommended by the Nextcloud 34 system requirements |
| `nginx` | `1.30.7` | Current stable branch |
| `paulczar/omgwtfssl` | pinned by digest | Unmaintained since 2021, amd64 only |

These versions are pinned but not yet tested together on a cluster.

**If you already run an older install of this setup:** Nextcloud can only be upgraded one major version at a time. Check your current version (Settings → Administration → Overview) and step through each major version (e.g. `nextcloud:32-apache`, then `33-apache`, then `34.0.6-apache`) instead of jumping straight to the pinned version. Make a backup of the database and the `nc-pv` folder first. MariaDB upgrades its data files automatically on start (`MARIADB_AUTO_UPGRADE`), but it cannot downgrade them: if your running MariaDB is already newer than 11.8 (check with `kubectl exec deploy/db -- mariadb --version`), pin that version instead.

## Prerequisites:
* A single-node Kubernetes cluster. All data is stored in folders on that node (`hostPath`), so these YAMLs do not work across several nodes.
* Basic Docker & Kubernetes knowledge

The original 2018 walkthrough (Ubuntu 18.04, Docker, `apt.kubernetes.io`) no longer works: the package repository was shut down and Kubernetes dropped direct Docker support in 1.24. Set up a cluster with the official guides instead:

1. Install a container runtime (containerd is the usual choice): https://kubernetes.io/docs/setup/production-environment/container-runtimes/
2. Install kubeadm, kubelet and kubectl: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
3. Create the cluster with `kubeadm init --pod-network-cidr=10.244.0.0/16`, following https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
4. Install the Flannel pod network: https://github.com/flannel-io/flannel
5. Allow normal Pods on the single node: `kubectl taint nodes --all node-role.kubernetes.io/control-plane-`

If you use a different pod network range, change `TRUSTED_PROXIES` in `nc-deployment.yaml` accordingly. A lighter alternative for a single machine is k3s (https://docs.k3s.io/quick-start); it ships its own Traefik ingress on ports 80/443, which would conflict with the nginx proxy Pod below unless disabled.

**Extra-hint:** Use the following in an extra-terminal to be able to see what the Kubernetes-cluster is doing
`$ watch -n 10 kubectl get deployment,svc,pods,pvc,pv,ing`

## Deployment + Service: MariaDB
As a user (not root) create a folder nc-deployment, download pre-defined MariaDB-descriptions, adjust it to your needs and deploy:
```
$ mkdir nc-deployment
$ cd nc-deployment
$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/db-deployment.yaml

$ nano db-deployment.yaml
--> change MYSQL_PASSWORD here
--> change MYSQL_ROOT_PASSWORD here
--> change db's HostPath here, which should be the absolute location of 'nc-deployment'/db-pv (eg /home/andremotz/nc-deployment/db-pv)

$ kubectl create -f db-deployment.yaml

$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/db-svc.yaml
$ kubectl create -f db-svc.yaml
```

## Deployment + Service: Nextcloud:
Next, download Nextcloud-descriptions, adjust them and deploy:
```
$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/nc-deployment.yaml

$ nano nc-deployment.yaml
--> change NEXTCLOUD_TRUSTED_DOMAINS and OVERWRITECLIURL to your server's name (the same name you will use for SSL_SUBJECT below)
--> change TRUSTED_PROXIES if your cluster's pod network is not 10.244.0.0/16
--> change NEXTCLOUD_ADMIN_PASSWORD
--> change MYSQL_PASSWORD (the value you've entered before)
--> change html's hostPath (eg. to /home/andremotz/nc-deployment/nc-pv)

$ kubectl create -f nc-deployment.yaml

$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/nc-svc.yaml
$ kubectl create -f nc-svc.yaml
```

## Create self-signed certificates
The [OMGWTFSSL-Docker image](https://hub.docker.com/r/paulczar/omgwtfssl/) offers easy-to-use certificate-creation. Here we are using only a Pod, not a Deployment. Once the certificates are created, the Pod will stop.
```
$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/omgwtfssl-pod.yaml

$ nano omgwtfssl-pod.yaml
--> change SSL_SUBJECT to your server's name
--> change CA_SUBJECT to your mail-adress
--> change SSL_KEY to a proper filename
--> change SSL_CSR to a proper filename
--> change SSL_CERT to a proper filename
--> change cert's hostPath (eg. to /home/andremotz/nc-deployment/certs-pv)

$ kubectl create -f omgwtfssl-pod.yaml
```
The certificate is valid for 365 days (`SSL_EXPIRE`) and is not renewed automatically. Before it expires, delete and re-create the Pod (`kubectl delete pod omgwtfssl && kubectl create -f omgwtfssl-pod.yaml`), then restart the proxy Pod.

## Deployment + Service: Nginx reverse Proxy
One could already easily adjust the Nextcloud-service to publish HTTP-driven service. However we want to use a Nginx-instance in front of our Nextcloud to be able to use HTTPS-encryption. For the proxy we are not using a Deployment but a Pod, to be able to make use of standard HTTP/HTTPS-ports 80 & 443
```
$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/nginx.conf

$ nano nginx.conf
--> change server_name (two locations in the file!) to the server name you've provided before for SSL_SUBJECT
--> change ssl_certificate to the filename you've provide before for SSL_CERT
--> change ssl_certificate_key to the filename you've provide before for SSL_KEY
--> if you changed PHP_UPLOAD_LIMIT in nc-deployment.yaml, change client_max_body_size to the same value

$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/proxy-pod.yaml

$ nano proxy-pod.yaml
--> change cert's hostPath to the location you have provided before
--> change nginx-config's hostpath to the location where you've stored nginx.conf before (eg. /home/andremotz/nc-deployment/nginx.conf)
--> change nginx-logs' hostpath to a proper location

$ kubectl create -f proxy-pod.yaml
```
Now you should be able to point your browser to https://<yourserver> and see a new Nextcloud-instance, running on a super-hyper nextlevel-Kubernetes cluster, that you could use for further cool stuff 😉
  
That’s it!! 😉
