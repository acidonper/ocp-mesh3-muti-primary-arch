#!/bin/bash
##
# Script to Install Openshift Service Mesh 3 Multi Arch Prerequisites
##

## Check Environment variables required 

if [[ "${CTX_CLUSTER1}" == "" || "${CTX_CLUSTER2}" == "" ]]
then
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} is NOT defined"
else
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} are defined"
fi


# Generate cert to trust both clusters

openssl genrsa -out /tmp/root-key.pem 4096

cat <<EOF > /tmp/root-ca.conf
encrypt_key = no
prompt = no
utf8 = yes
default_md = sha256
default_bits = 4096
req_extensions = req_ext
x509_extensions = req_ext
distinguished_name = req_dn
[ req_ext ]
subjectKeyIdentifier = hash
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, nonRepudiation, keyEncipherment, keyCertSign
[ req_dn ]
O = Istio
CN = Root CA
EOF

openssl req -sha256 -new -key /tmp/root-key.pem -config /tmp/root-ca.conf -out /tmp/root-cert.csr

openssl x509 -req -sha256 -days 3650 -signkey /tmp/root-key.pem -extensions req_ext -extfile /tmp/root-ca.conf -in /tmp/root-cert.csr -out /tmp/root-cert.pem


# Generate certs cluster01

mkdir /tmp/cluster01

openssl genrsa -out /tmp/cluster01/ca-key.pem 4096

cat <<EOF > /tmp/cluster01/ca-intermediate.conf
[ req ]
encrypt_key = no
prompt = no
utf8 = yes
default_md = sha256
default_bits = 4096
req_extensions = req_ext
x509_extensions = req_ext
distinguished_name = req_dn
[ req_ext ]
subjectKeyIdentifier = hash
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, nonRepudiation, keyEncipherment, keyCertSign
subjectAltName=@san
[ san ]
DNS.1 = istiod.istio-system.svc
[ req_dn ]
O = Istio
CN = Intermediate CA
L = cluster01
EOF

openssl req -new -config /tmp/cluster01/ca-intermediate.conf -key /tmp/cluster01/ca-key.pem -out /tmp/cluster01/cluster-ca.csr

openssl x509 -req -sha256 -days 3650 -CA /tmp/root-cert.pem -CAkey /tmp/root-key.pem -CAcreateserial -extensions req_ext -extfile /tmp/cluster01/ca-intermediate.conf -in /tmp/cluster01/cluster-ca.csr -out /tmp/cluster01/ca-cert.pem

cat /tmp/cluster01/ca-cert.pem /tmp/root-cert.pem > /tmp/cluster01/cert-chain.pem && cp /tmp/root-cert.pem /tmp/cluster01


# Generate Cert cluster02

mkdir /tmp/cluster02

openssl genrsa -out /tmp/cluster02/ca-key.pem 4096

cat <<EOF > /tmp/cluster02/ca-intermediate.conf
[ req ]
encrypt_key = no
prompt = no
utf8 = yes
default_md = sha256
default_bits = 4096
req_extensions = req_ext
x509_extensions = req_ext
distinguished_name = req_dn
[ req_ext ]
subjectKeyIdentifier = hash
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, nonRepudiation, keyEncipherment, keyCertSign
subjectAltName=@san
[ san ]
DNS.1 = istiod.istio-system.svc
[ req_dn ]
O = Istio
CN = Intermediate CA
L = cluster02
EOF

openssl req -new -config /tmp/cluster02/ca-intermediate.conf -key /tmp/cluster02/ca-key.pem -out /tmp/cluster02/cluster-ca.csr

openssl x509 -req -sha256 -days 3650 -CA /tmp/root-cert.pem -CAkey /tmp/root-key.pem -CAcreateserial -extensions req_ext -extfile /tmp/cluster02/ca-intermediate.conf -in /tmp/cluster02/cluster-ca.csr -out /tmp/cluster02/ca-cert.pem

cat /tmp/cluster02/ca-cert.pem /tmp/root-cert.pem > /tmp/cluster02/cert-chain.pem && cp /tmp/root-cert.pem /tmp/cluster02


## Create Projects and certificates in OCP

oc get project istio-system-cluster01 --context ${CTX_CLUSTER1} || oc new-project istio-system-cluster01 --context ${CTX_CLUSTER1}
oc --context ${CTX_CLUSTER1} label namespace istio-system-cluster01 topology.istio.io/network=network1
oc get secret -n istio-system-cluster01 --context ${CTX_CLUSTER1} cacerts || oc create secret generic cacerts -n istio-system-cluster01 --context ${CTX_CLUSTER1} --from-file=/tmp/cluster01/ca-cert.pem --from-file=/tmp/cluster01/ca-key.pem --from-file=/tmp/cluster01/root-cert.pem --from-file=/tmp/cluster01/cert-chain.pem

oc get project istio-system-cluster02 --context ${CTX_CLUSTER2} || oc new-project istio-system-cluster02 --context ${CTX_CLUSTER2}
oc --context ${CTX_CLUSTER2} label namespace istio-system-cluster02 topology.istio.io/network=network2
oc get secret -n istio-system-cluster02 --context ${CTX_CLUSTER2} cacerts || oc create secret generic cacerts -n istio-system-cluster02 --context ${CTX_CLUSTER2} --from-file=/tmp/cluster02/ca-cert.pem --from-file=/tmp/cluster02/ca-key.pem --from-file=/tmp/cluster02/root-cert.pem --from-file=/tmp/cluster02/cert-chain.pem
