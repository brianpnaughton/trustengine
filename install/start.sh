#!/bin/bash
set -o errexit

############################################
# Start a local Kubernetes cluster using kind
############################################

CURRENT_DIR=$(pwd)
# remove install from the end of the CURRENT_DIR to get the ROOT directory
CURRENT_DIR=${CURRENT_DIR%/install}

echo "Current directory: ${CURRENT_DIR}"

# check if kind is installed
if ! command -v kind &> /dev/null
then
    echo "kind could not be found.."
    exit 1
fi

# check if helm is installed
if ! command -v helm &> /dev/null
then
    echo "helm could not be found.."
    exit 1
fi

# check if kubectl is installed
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found.."
    exit 1
fi

# # check if cloud-provider-kind is installed
# if ! command -v cloud-provider-kind &> /dev/null
# then
#     echo "cloud-provider-kind could not be found.. you can download it from https://github.com/kubernetes-sigs/cloud-provider-kind/releases"
#     exit 1
# fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Linux OS detected.. increasing inotify limits"
  sudo sysctl fs.inotify.max_user_watches=524288
  sudo sysctl fs.inotify.max_user_instances=512
fi

# Start a local registry in Docker
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

############################################
# build and push images
############################################
echo "Building and pushing images to local registry.."

echo "Building KnowledgeDB at ${CURRENT_DIR}/services/postgres/knowledgedb.Dockerfile"
docker build -t knowledgedb -f ${CURRENT_DIR}/services/postgres/knowledgedb.Dockerfile .
docker tag knowledgedb localhost:5001/knowledgedb:latest
docker push localhost:5001/knowledgedb:latest

# docker build -t ageviewer -f ${CURRENT_DIR}/services/postgres/ageviewer.Dockerfile .
# docker tag ageviewer localhost:5001/ageviewer:latest
# docker push localhost:5001/ageviewer:latest

echo "Building Network Operator at ${CURRENT_DIR}/operator/Dockerfile"
cd ${CURRENT_DIR}/operator/
docker build -t networkoperator .
docker tag networkoperator localhost:5001/networkoperator:latest
docker push localhost:5001/networkoperator:latest
cd ${CURRENT_DIR}/install

#############################################
# Pull the KinD node image and create cluster
#############################################
docker pull kindest/node:v1.32.0

if [ -z "$(kind get clusters)" ]; then
# Create a cluster with the local registry enabled in containerd
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30000
        hostPort: 8080
  - role: worker
    labels:
      app: services
  - role: worker
    labels:
      app: knowledgedb
    extraMounts:
      - hostPath: ${CURRENT_DIR}/services/postgres/data
        containerPath: /storage
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
EOF
fi

# Connect the registry to the cluster network
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

################################################################################################
# Deploy the application
################################################################################################
kubectl apply -f ${CURRENT_DIR}/services/postgres/knowledgedb.yaml
# kubectl apply -f ${CURRENT_DIR}/services/postgres/viewer.yaml

# Deploy the network operator and CRDs
kubectl apply -f ${CURRENT_DIR}/operator/deployment.yaml
kubectl apply -f ${CURRENT_DIR}/operator/config

################################################################################################
# Start cloud-provider-kind
################################################################################################
# echo "Enter your sudo password to start cloud-provider-kind"
# read -s ROOT_PASSWORD
# echo ${ROOT_PASSWORD} | sudo -S cloud-provider-kind > ${CURRENT_DIR}/cloud-provider-kind.log 2>&1 &
# echo "Started cloud-provider-kind, logs can be found in ${CURRENT_DIR}/cloud-provider-kind.log"

################################################################################################
# K8s dashboard - https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
################################################################################################
# helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
# helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   name: admin-user
#   namespace: kubernetes-dashboard
# EOF

# cat <<EOF | kubectl apply -f -
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: admin-user
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: cluster-admin
# subjects:
# - kind: ServiceAccount
#   name: admin-user
#   namespace: kubernetes-dashboard
# EOF

# # Get the bearer token for the admin-user serviceaccount
# echo "Bearer token for admin-user serviceaccount:"
# kubectl -n kubernetes-dashboard create token admin-user