## Prerequisites
- Docker
- criu (For now install via apt package manager is broken on LTS Ubuntu so install from [source](https://criu.org/Installation))
  - `sudo apt install libprotobuf-dev libprotobuf-c-dev protobuf-c-compiler protobuf-compiler python3-protobuf libnl-3-dev libcap-dev` 
  - `sudo apt install --no-install-recommends pkg-config libbsd-dev iproute2 nftables  libcap-dev libnet-dev libaio-dev python3-future libdrm-dev`
  - `sudo apt install asciidoc xmlto --no-install-recommends`   
- Enable experimental Docker
  - `echo "{\"experimental\": true}" >> /etc/docker/daemon.json` (For Docker Desktop via GUI)
  - restart Docker

1. Checkpoint and restore running Docker container
    - base image is Alpine, so we use ash instead of bash
    - entrypoint is a simple while loop that print a  continuous sequence of numbers 
    - 

2. Checkpoint and restore Kubernetes pods