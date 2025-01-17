#!/bin/bash
##
# Script to create a control plane in cluster01
##

## Check Environment variables required 

if [[ "${CTX_CLUSTER1}" == "" || "${CTX_CLUSTER2}" == "" ]]
then
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} is NOT defined"
else
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} are defined"
fi

# Please not change NETWORK and ZONE values

ZONE=mesh1
NET=network1
REGION=cluster01
CP_NAME=istio-system-${REGION}
CP_VERSION=v1.24.1

oc get operators servicemeshoperator3.openshift-operators --context="${CTX_CLUSTER1}"

[[ $? -eq 0 ]] || { echo >&2 "It is required to have Service Mesh 3 operator already installed in Openshift"; exit 1; }

# oc label namespace ${CP_NAME} istio-discovery=enabled --context="${CTX_CLUSTER1}"
oc --context="${CTX_CLUSTER1}" label namespace ${CP_NAME} topology.istio.io/network=${NET}

oc new-project istio-cni --context="${CTX_CLUSTER1}"

oc apply --context="${CTX_CLUSTER1}" -f - <<EOF
apiVersion: sailoperator.io/v1alpha1
kind: IstioCNI
metadata:
  name: default
spec:
  namespace: istio-cni
  version: ${CP_VERSION}
EOF

sleep 10

oc apply --context="${CTX_CLUSTER1}" -f - <<EOF
apiVersion: sailoperator.io/v1alpha1
kind: Istio
metadata:
  name: ${CP_NAME}
spec:
  version: ${CP_VERSION}
  namespace: ${CP_NAME}
  updateStrategy:
    type: InPlace
  values:
    meshConfig:
      discoverySelectors:
        - matchLabels:
            istio-discovery: enabled
    global:
      meshID: ${ZONE}
      multiCluster:
        clusterName: ${REGION}
      network: ${NET}
    pilot:
      resources:
        requests:
          cpu: 100m
          memory: 1024Mi
EOF

oc --context "${CTX_CLUSTER1}" wait --for condition=Ready istio/${CP_NAME} --timeout=3m

oc apply -f files/config/gws-cluster01.yaml -n ${CP_NAME} --context="${CTX_CLUSTER1}"

sleep 30

oc new-project bookinfo --context="${CTX_CLUSTER1}"
oc label namespace bookinfo istio-discovery=enabled istio.io/rev=${CP_NAME} --context="${CTX_CLUSTER1}"

oc apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/bookinfo/platform/kube/bookinfo.yaml -n bookinfo --context="${CTX_CLUSTER1}"

sleep 60

oc exec "$(oc get pod --context="${CTX_CLUSTER1}" -l app=ratings -n bookinfo -o jsonpath='{.items[0].metadata.name}')" -c ratings -n bookinfo --context="${CTX_CLUSTER1}" -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"
