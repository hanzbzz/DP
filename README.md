### Versions

| Tool               | Original repo                            | Original branch  | Forked repo                            | Forked branch          |
|--------------------|------------------------------------------|------------------|----------------------------------------|------------------------|
| Kubernetes         | https://github.com/kubernetes/kubernetes | release-1.31     | https://github.com/hanzbzz/kubernetes/ | release-1.31-brazda    |
| Containerd         | https://github.com/containerd/containerd | release/2.0      | https://github.com/hanzbzz/containerd/ | release-2.0-brazda-dev |
| Criu               | https://github.com/rst0git/criu          | encrypted-images | https://github.com/hanzbzz/criu/       | encrypted-images       |
| Runc               | https://github.com/opencontainers/runc   | release-1.2      | https://github.com/hanzbzz/runc/       | release-1.2-brazda     |
| Kind (development) | https://github.com/kubernetes-sigs/kind  | v0.25.0          | https://github.com/hanzbzz/kind/       | v0.25.0-brazda         |

### Setup

1. Clone this repository `git clone https://github.com/hanzbzz/DP.git`
2. Pull source code for submodules `git submodule update --init --recursive`
3. Build kind `cd kind && git checkout v0.25.0-brazda && go install . && cd -`

    3.1 Test with `kind --version`, should be `kind version 0.25.0`
4. Build kind base image with updated version of containerd `cd kind/images/base && CONTAINERD_VERSION=release-2.0-brazda-dev make quick && cd -`
5. Look for tag of the base image built in previous step `docker image ls gcr.io/k8s-staging-kind/base`
6. Build the node image, passing the base image. Replace \<TAG\> with tag from last step `kind build node-image ~/DP/kubernetes  --base-image gcr.io/k8s-staging-kind/base:<TAG>`
7. Create the kind cluster, passing it the node image built in previous step and config from this repo `kind create cluster --image kindest/node:latest --config cr-kubernetes/cluster.yaml`
8. Build the counter container used for testing `cd cr-docker && docker build . -t counter && cd -`
9. Load the counter image into kind cluster `kind load docker-image counter:latest`
10. Create a pod with the counter container `kubectl apply -f cr-kubernetes/counter-pod.yaml`
11. Verify counter pod is running `kubectl get pods -o wide`
12. Open second terminal and create a proxy for the Kubernetes API `kubectl proxy`
13. Create checkpoint of the counter pod, and leave the pod running `curl 'localhost:8001/api/v1/namespaces/default/pods/counter/checkpoint' -X POST -d '{"leaveRunning":true,"encrypt":true,"encryptionSecret":"test-secret"}' -H "Content-type: application/json"`

### Request

## URL

The url looks like this `localhost:8001/api/v1/namespaces/<NAMESPACE>/pods/<POD>/checkpoint`
where `<POD>` is the name of the we want to checkpoint and `<NAMESPACE>` is the namespace where it's located

## Params

The request accepts following parametrs as items in the JSON request

| Name             | Type   | Default | Values             | Note                                                                                                    |
|------------------|--------|---------|--------------------|---------------------------------------------------------------------------------------------------------|
| leaveRunning     | bool   | true    | true/false         | When set to false, will delete the pod after checkpoint is finished                                     |
| encrypt          | bool   | false   | true/false         | Controls if resulting checkpoint should be encrypted. When true, encryptionSecret needs to be specified |
| encryptionSecret | string | ""      | Secret of type TLS | Kubernetes secret of type TLS. The certificate will be used to encrypt the checkpoint                   |