# Script to build and create a new kind cluster with the latest version of containd

# build kind base image
cd kind/images/base && make quick && cd -
# get tag of the image
BASE_IMAGE_TAG_LATEST=$(docker image list gcr.io/k8s-staging-kind/base --format "{{.Tag}}" | head -n 1)
kind build node-image ~/DP/kubernetes --base-image gcr.io/k8s-staging-kind/base:$BASE_IMAGE_TAG_LATEST
# delete previous cluster
kind delete cluster
kind create cluster --image kindest/node:latest --config ~/DP/kube-deployments/cluster.yaml
kind load docker-image counter:latest
kubectl apply -f ~/DP/kube-deployments/counter-pod.yaml
# kill previous proxy process
pkill -7 -f 'kubectl proxy'
kubectl proxy &
sleep 2
echo "DONE"
