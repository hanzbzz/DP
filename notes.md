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
