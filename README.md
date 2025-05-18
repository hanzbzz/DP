### Versions

| Tool               | Original repo                            | Original branch  | Forked repo                            | Forked branch          |
|--------------------|------------------------------------------|------------------|----------------------------------------|------------------------|
| Kubernetes         | https://github.com/kubernetes/kubernetes | release-1.31     | https://github.com/hanzbzz/kubernetes/ | release-1.31-brazda    |
| Containerd         | https://github.com/containerd/containerd | release/2.0      | https://github.com/hanzbzz/containerd/ | release-2.0-brazda-dev |
| Criu               | https://github.com/rst0git/criu          | encrypted-images | https://github.com/hanzbzz/criu/       | encrypted-images       |
| Runc               | https://github.com/opencontainers/runc   | release-1.2      | https://github.com/hanzbzz/runc/       | release-1.2-brazda     |
| Kind (development) | https://github.com/kubernetes-sigs/kind  | v0.25.0          | https://github.com/hanzbzz/kind/       | v0.25.0-brazda         |


### Setup Rancher/RKE2
1. Clone this repository `git clone https://github.com/hanzbzz/DP.git`
2. Pull source code for submodules `git submodule update --init --recursive`
3. Install [RKE2](https://docs.rke2.io/install/quickstart)
4. Build containerd `cd containerd && make && cd -`

    4.1 Backup old containerd binaries ```mv /var/lib/rancher/rke2/bin/containerd /var/lib/rancher/rke2/bin/containerd.old && mv /var/lib/rancher/rke2/bin/containerd-shim-runc-v2 /var/lib/rancher/rke2/bin/containerd-shim-runc-v2.old && mv /var/lib/rancher/rke2/bin/ctr /var/lib/rancher/rke2/bin/ctr.old```
    
    4.2 Copy newly built binaries ```cp containerd/bin/containerd /var/lib/rancher/rke2/bin/containerd  && 
cp containerd/bin/ctr /var/lib/rancher/rke2/bin/ctr && 
cp containerd/bin/containerd-shim-runc-v2 /var/lib/rancher/rke2/bin/containerd-shim-runc-v2```
5. Build runc `cd runc && make && cd -`

    5.1 Replace runc binary `mv /var/lib/rancher/rke2/bin/runc /var/lib/rancher/rke2/bin/runc.old && cp runc/runc /var/lib/rancher/rke2/bin/runc`
6. Build kubernetes `cd kubernetes/ && build/run.sh make && cd -`

    6.1 Replace kubelet binary `mv /var/lib/rancher/rke2/bin/kubelet /var/lib/rancher/rke2/bin/kubelet.old && cp kubernetes/_output/dockerized/bin/linux/amd64/kubelet /var/lib/rancher/rke2/bin/kubelet`

    6.2 (Optional) We will also need to use the newly built image for kube-apiserver, but I already uploaded the latest version to dockerhub, so you don't need to do this

        6.2.1 Build the release images `kubernetes/build/release-images.sh`

        6.2.1 Load the docker image from tar `docker image load -i kubernetes/_output/release-images/amd64/kube-apiserver.tar`
        
        6.2.2 Tag the image `docker tag <LOADED_IMAGE_NAME> <TAG>`

        6.2.3 Push the image `docker push <TAG>`

7. Build criu `cd criu && make && cd -`

    7.1 Copy criu binary `cp criu/criu/criu /var/lib/rancher/rke2/bin/`

8. Create `/etc/rancher/rke2/config.yaml` file with the contents below, potentially overwriting the `kube-apiserver-image` with the one you build in step 6.2
```
kube-controller-manager-arg:
  - "feature-gates=ContainerCheckpoint=true"

kube-apiserver-arg:
  - "feature-gates=ContainerCheckpoint=true"

kubelet-arg:
  - "feature-gates=ContainerCheckpoint=true"

kube-apiserver-image: "hzbzzz/kube-apiserver-checkpoint"
```

9. Restart rke-server service `sudo systemctl restart rke2-server.service`


### Setup KiND cluster

1. Clone this repository `git clone https://github.com/hanzbzz/DP.git`
2. Pull source code for submodules `git submodule update --init --recursive`
3. Build kind `cd kind && git checkout v0.25.0-brazda && go install . && cd -`

    3.1 Test with `kind --version`, should be `kind version 0.25.0`
4. Build kind base image with updated version of containerd `cd kind/images/base && CONTAINERD_VERSION=release-2.0-brazda make quick && cd -`
5. Look for tag of the base image built in previous step `docker image ls gcr.io/k8s-staging-kind/base`
6. Build the node image, passing the base image. Replace \<TAG\> with tag from last step `kind build node-image ~/DP/kubernetes  --base-image gcr.io/k8s-staging-kind/base:<TAG>`
7. Create the kind cluster, passing it the node image built in previous step and config from this repo `kind create cluster --image kindest/node:latest --config kube-deployments/cluster.yaml`
8. Build the counter container used for testing `cd counter-container && docker build . -t counter && cd -`
9. Load the counter image into kind cluster `kind load docker-image counter:latest`
10. Create a pod with the counter container `kubectl apply -f kube-deployments/counter-pod.yaml`
11. Verify counter pod is running `kubectl get pods -o wide`
12. Open second terminal and create a proxy for the Kubernetes API `kubectl proxy`
13. Create checkpoint of the counter pod, and leave the pod running `curl 'localhost:8001/api/v1/namespaces/default/pods/counter/checkpoint' -X POST -d '{"leaveRunning":true,"encrypt":true,"encryptionSecret":"test-secret"}' -H "Content-type: application/json"`

### Request

## URL

The url looks like this `<APISEVER_HOST>:6443/api/v1/namespaces/<NAMESPACE>/pods/<POD>/checkpoint`
where `<POD>` is the name of the we want to checkpoint and `<NAMESPACE>` is the namespace where it's located

## Params

The request accepts following parametrs as items in the JSON request

| Name             | Type   | Default | Values             | Note                                                                                                    |
|------------------|--------|---------|--------------------|---------------------------------------------------------------------------------------------------------|
| leaveRunning     | bool   | true    | true/false         | When set to false, will delete the pod after checkpoint is finished                                     |
| encrypt          | bool   | true   | true/false         | Controls if resulting checkpoint should be encrypted. When true, encryptionSecret needs to be specified |
| encryptionSecret | string | ""      | Secret of type TLS | Kubernetes secret of type TLS. The certificate will be used to encrypt the checkpoint                   |
| timeout | integer | 34      | Integer | Time after which the request will time out.                   |
| container | string | "" | Container name | If Pod has more contaienrs, this can specify the one to be checkpointed. Default is the first in the Pod specification |