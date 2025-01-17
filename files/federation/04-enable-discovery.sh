#!/bin/bash
##
# Script to Enable Endpoint Discovery
##

## Check Environment variables required 

if [[ "${CTX_CLUSTER1}" == "" || "${CTX_CLUSTER2}" == "" ]]
then
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} is NOT defined"
else
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} are defined"
fi


oc project --context="${CTX_CLUSTER2}" istio-system-cluster02
oc project --context="${CTX_CLUSTER1}" istio-system-cluster01

istioctl create-remote-secret \
    --context="${CTX_CLUSTER1}" \
    --name=cluster01 | \
    kubectl apply -f - --context="${CTX_CLUSTER2}"

istioctl create-remote-secret \
    --context="${CTX_CLUSTER2}" \
    --name=cluster02 | \
    kubectl apply -f - --context="${CTX_CLUSTER1}"
