#!/bin/bash
##
# Script to Create a multicluster App in cluster01
##

## Check Environment variables required 

if [[ "${CTX_CLUSTER1}" == "" || "${CTX_CLUSTER2}" == "" ]]
then
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} is NOT defined"
else
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} are defined"
fi


REGION=cluster01
REGION_EXT=cluster02
CP_NAME_01=istio-system-${REGION}
CP_NAME_02=istio-system-${REGION_EXT}

## Install a Federated service cluster01

oc create --context="${CTX_CLUSTER1}" namespace sample

oc label --context="${CTX_CLUSTER1}" namespace sample istio-discovery=enabled istio.io/rev=${CP_NAME_01}

oc apply --context="${CTX_CLUSTER1}" -f samples/helloworld/helloworld.yaml -l service=helloworld -n sample

oc apply --context="${CTX_CLUSTER1}" \
    -f samples/helloworld/helloworld.yaml \
    -l version=v1 -n sample

oc get pod --context="${CTX_CLUSTER1}" -n sample -l app=helloworld

sleep 10


## Install a Federated service cluster02

oc create --context="${CTX_CLUSTER2}" namespace sample

oc label --context="${CTX_CLUSTER2}" namespace sample istio-discovery=enabled istio.io/rev=${CP_NAME_02}

oc apply --context="${CTX_CLUSTER2}" -f samples/helloworld/helloworld.yaml -l service=helloworld -n sample

oc apply --context="${CTX_CLUSTER2}" \
    -f samples/helloworld/helloworld.yaml \
    -l version=v2 -n sample

oc get pod --context="${CTX_CLUSTER2}" -n sample -l app=helloworld

sleep 10


# Test multicluster service

oc apply --context="${CTX_CLUSTER2}" \
    -f samples/curl/curl.yaml -n sample
oc apply --context="${CTX_CLUSTER1}" \
    -f samples/curl/curl.yaml -n sample

sleep 30

oc get pod --context="${CTX_CLUSTER1}" -n sample -l app=curl
oc get pod --context="${CTX_CLUSTER2}" -n sample -l app=curl

sleep 10

oc exec --context="${CTX_CLUSTER1}" -n sample -c curl "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}')" -- curl -sS helloworld.sample:5000/hello
oc exec --context="${CTX_CLUSTER1}" -n sample -c curl "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}')" -- curl -sS helloworld.sample:5000/hello
oc exec --context="${CTX_CLUSTER1}" -n sample -c curl "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}')" -- curl -sS helloworld.sample:5000/hello

oc exec --context="${CTX_CLUSTER2}" -n sample -c curl "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}')" -- curl -sS helloworld.sample:5000/hello
oc exec --context="${CTX_CLUSTER2}" -n sample -c curl "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}')" -- curl -sS helloworld.sample:5000/hello
oc exec --context="${CTX_CLUSTER2}" -n sample -c curl "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}')" -- curl -sS helloworld.sample:5000/hello