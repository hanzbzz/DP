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
- All of the above changes are already done in my fork of kind repository.
- Build custom version of kind `cd kind && go install . && cd -`
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