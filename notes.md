## Prerequisites

- Docker
- criu (For now install via apt package manager is broken on LTS Ubuntu so install from [source](https://criu.org/Installation))
  - `sudo apt install libprotobuf-dev libprotobuf-c-dev protobuf-c-compiler protobuf-compiler python3-protobuf libnl-3-dev libcap-dev`
  - `sudo apt install --no-install-recommends pkg-config libbsd-dev iproute2 nftables  libcap-dev libnet-dev libaio-dev python3-future libdrm-dev`
  - `sudo apt install asciidoc xmlto --no-install-recommends`
  - When installing via package manager make to add the ppa repo of riu to have latest version
- Enable experimental Docker
  - `echo "{\"experimental\": true}" >> /etc/docker/daemon.json` (For Docker Desktop via GUI)
  - restart Docker
- Kubernetes (my fork is part of this repo)
- [kind](https://kind.sigs.k8s.io/)
- Tools to [build](https://github.com/kubernetes/community/blob/master/contributors/devel/development.md#building-kubernetes-with-docker) Kubernetes

## Progress

### Checkpoint and restore running Docker container

- base image is Alpine, so we use ash instead of bash
- entrypoint is a simple while loop that print a  continuous sequence of numbers
- With prerequisites satisfied, checkpoint and restore is very simple

```bash
docker run -d cr-docker-test
c3e845905b4ed40d8c8a7a0a338f68db2ccb0c3d225d4269d931ec6b39fc6943
docker checkpoint create c3e checkpoint1
docker start --checkpoint checkpoint1 c3e
```

### Checkpoint and restore Kubernetes pod

The below instructions are only relevant for my local development environment. If you have Kubernetes cluster with containerd 2.0.0, only the last step is needed(probably)

- It seems that containerd supports checkpoint/restore with Kubernetes only since version 2.0.0 [reddit](https://www.reddit.com/r/kubernetes/comments/1em8bed/checkpointcontainer_not_implemented/?rdt=38992)
- So the solution should be to build `kind` base image with version 2.0.0
- However this version is not supported by kind [github](https://github.com/kubernetes-sigs/kind/issues/3768)
- To load local images into kind with containerd 2.0.0, the import command in kind binary needs to be edited [github](https://github.com/containerd/runwasi/issues/579)
- CRIU needs to be installed in the base image of kind
- All of the above changes are already done in my fork of kind repository. Run `git submodule update --init` in the root directory to pull the submodules.
- Build custom version of kind `cd kind && git checkout containerd_2.0.0_support && go install . && cd -`
- Build base image of kind `cd kind/images/base && make quick && cd -`
- Build node image for kind. Note that the path to  kubernetes repo needs to be absolute and the base image argument should be the image built in previous step

```bash
kind build node-image /home/jan/DP/kubernetes  --base-image gcr.io/k8s-staging-kind/base:v20241121-74acdf74-dirty
```

- Create kind cluster with the built node image `kind create cluster --image kindest/node:latest --config cr-kubernetes/cluster.yaml`
- Load the docker image build previously into the cluster `kind load docker-image counter:latest`
- Run the pod with this image `kubectl apply -f cr-kubernetes/counter-pod.yaml`
- Perform the checkpoint

```bash
docker exec -it kind-control-plane curl -X POST -k --cert /etc/kubernetes/pki/apiserver-kubelet-client.crt --key /etc/kubernetes/pki/apiserver-kubelet-client.key "https://localhost:10250/checkpoint/default/counter/counter-container"
```

- Now the tar archive representing the running container is stored in the kind-control-plane container.

### Adding checkpoint endpoint to Kubernetes api

- Main source [github](https://github.com/kubernetes/kubernetes/pull/97194)
- cri remote runtime from [this](https://github.com/kubernetes/kubernetes/pull/97194/commits/022347fb893cba09a7a92129bae0cb9c47d495b4) commit was moved to `staging/src/k8s.io/cri-client`
- api strucutre [github](https://github.com/kubernetes/kubernetes/tree/master/staging/src/k8s.io/api)
- Kubernetes supports checkpointing of a single container, but the above pull request implements checkpointing of pods
- follow the code at /home/jan/DP/kubernetes/pkg/registry/core/rest/storage_core.go to see how http requests are made
- It was necessary to change the request method on the kubelet checkpoint api from POST to GET. Not sure what implications this has
- start proxy to the Kubernetes API with `kubectl proxy`
- `curl 'localhost:8001/api/v1/namespaces/default/pods/counter/checkpoint?container=counter-container'`
- GET/POST request for checkpoint
- `curl 'localhost:8001/api/v1/namespaces/default/pods/counter/checkpoint' -X POST -d '{"container":"counter-container"}' -H "Content-type: application/json"`

### Adding option to kill container after checkpoint

- Needs update of containerd code [github](https://github.com/containerd/containerd)
- The code to pass options to criu is at `containerd/internal/cri/server/container_checkpoint_linux.go`

### How to run this

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
13. Create checkpoint of the counter pod, and leave the pod running `curl 'localhost:8001/api/v1/namespaces/default/pods/counter/checkpoint' -X POST -d '{"container":"counter-container", "exit":false}' -H "Content-type: application/json"`
