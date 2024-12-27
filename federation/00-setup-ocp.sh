#!/bin/bash
##
# Script to prepare Openshift Laboratory
##

## Check Environment variables required 

if [[ "${CTX_CLUSTER1}" == "" || "${CTX_CLUSTER2}" == "" ]]
then
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} is NOT defined"
else
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} are defined"
fi


##
# Users 
##
USERS="user1
user2"


##
# Adding user to htpasswd
##
htpasswd -c -b users.htpasswd admin password
for i in $USERS
do
  htpasswd -b users.htpasswd $i $i
done


##
# Creating htpasswd file in Openshift
##
oc delete secret lab-users -n openshift-config --context ${CTX_CLUSTER1}
oc delete secret lab-users -n openshift-config --context ${CTX_CLUSTER2}
oc create secret generic lab-users --from-file=htpasswd=users.htpasswd -n openshift-config --context ${CTX_CLUSTER1}
oc create secret generic lab-users --from-file=htpasswd=users.htpasswd -n openshift-config --context ${CTX_CLUSTER2}


##
# Configuring OAuth to authenticate users via htpasswd
##
cat <<EOF > /tmp/oauth.yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - htpasswd:
      fileData:
        name: lab-users
    mappingMethod: claim
    name: lab-users
    type: HTPasswd
EOF

cat /tmp/oauth.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/oauth.yaml | oc apply --context ${CTX_CLUSTER2} -f -
oc adm policy add-cluster-role-to-user cluster-admin admin --context ${CTX_CLUSTER1}
oc adm policy add-cluster-role-to-user cluster-admin admin --context ${CTX_CLUSTER2}

