# Nextcloud on Kubernetes
nextcloud for kubernetes

For more background information check out my blog-post at https://www.andremotz.com/nextcloud-docker-on-kubernetes-cluster-ssl-certificates/ 

These YAMLs can be used on a Kubernetes-cluster to set-up a Nextcloud using MariaDB and Nginx as a SSL/TLS-Proxy. The YAMLs were tested on Ubuntu 18.04 but should be compatible with any Kubernetes-cluster.

## Prerequisites:
* Installed Ubuntu 18.04 
* Basic Docker & Kubernetes knowledge

Source: https://linuxconfig.org/how-to-install-kubernetes-on-ubuntu-18-04-bionic-beaver-linux

```
$ sudo apt update && sudo apt upgrade -y
$ sudo apt install docker.io
$ sudo systemctl enable docker
$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
$ sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
$ sudo apt install kubeadm
$ sudo swapoff -a
$ sudo kubeadm init --pod-network-cidr=10.244.0.0/16
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
$ kubectl taint nodes --all node-role.kubernetes.io/master-
```
At this place you should note down the shown kubeadm join-message in your console to be able to connect further Kubernetes-nodes in the future.

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
--> change NEXTCLOUD_URL
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

## Deployment + Service: Nginx reverse Proxy
One could already easily adjust the Nextcloud-service to publish HTTP-driven service. However we want to use a Nginx-instance in front of our Nextcloud to be able to use HTTPS-encryption. For the proxy we are not using a Deployment but a Pod, to be able to make use of standard HTTP/HTTPS-ports 80 & 443
```
$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/nginx.conf

$ nano nginx.conf
--> change server_name (two locations in the file!) to the server name you've provided before for SSL_SUBJECT
--> change ssl_certificate to the filename you've provide before for SSL_CERT
--> change ssl_certificate_key to the filename you've provide before for SSL_KEY

$ wget https://raw.githubusercontent.com/andremotz/nextcloud-kubernetes/master/kubernetes-yaml/proxy-pod.yaml

$ nano proxy-pod.yaml
--> change cert's hostPath to the location you have provided before---> change nginx-config's hostpath to the location where you've stored nginx.conf before (eg. /home/andremotz/nc-deployment/nginx.conf)
--> change nginx-logs' hostpath to a proper location

$ kubectl create -f proxy-pod.yaml
```
Now you should be able to point your browser to https://<yourserver> and see a new Nextcloud-instance, running on a super-hyper nextlevel-Kubernetes cluster, that you could use for further cool stuff 😉

That’s it!! 😉
