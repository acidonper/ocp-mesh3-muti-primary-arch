# Openshift Service Mesh 3 Federation

This document collects a set of procedures to install Openshift Service Mesh 3 (TP1) in two Opeshift Clusters and configure a federation mesh between them.

This guide is designed to install the Istio control plane on both cluster01 and cluster02 implementing a multi-primary architecture, making each a primary cluster. Both clusters reside on the network1 and network2, meaning there is direct connectivity between the pods in both clusters.

## Prerequisites

It is required a set of prerequisites to setting up a Service Mesh 3.0 federation environment previously to be ablñe to execute the procedures included in this document:

- 2 Openshift Clusters 4.16+
- An AWS account with S3 activated (2 S3 buckets)
- Access admin privileges to these clusters

In terms of operators, it is required to install the following operators Manually

- Service Mesh 3 tp01
- Kiali 1.89.4
- Tempo
- Distributed Tracing
- Red Hat build of OpenTelemetry

## Setting Up OSSM 3 multi cluster

The first step is to define CLUSTER01 and CLUSTER02 environment variables and introduce the respective cluster credentials to be able to access to the clusters executing the following procedure:

```$bash
CLUSTER01="https://api.acidonpe133.sandbox2401.opentlc.com:6443"

oc login -u kubeadmin $CLUSTER01
export CTX_CLUSTER1=$(oc config current-context)

CLUSTER02="https://api.cluster-8xcvn.8xcvn.sandbox385.opentlc.com:6443"
oc login -u kubeadmin $CLUSTER02
export CTX_CLUSTER2=$(oc config current-context)
```

Once the CTX_CLUSTERX env variables have been defined, please execute the respective script for setting up the Openshift clusters:

### Setup OCP

This script install an identity provider based on a HTTPASSWD file in order to be able to use local users to access to the cluster with admin, or not, permissions.

Please execute the following script to perform this configuration:

```$bash
sh files/federation/00-setup-ocp.sh
```

Once the script has been executed succesfully, it will be possible to access to the cluster with the user **admin:password**.

### Setup Service Mesh Prerequisites

In order to be able to federate services between multiple clusters using a multi-primary architecture, it is required to generate a set of certificates in both clusters using a common CA entity. 

Please execute the following script to perform this configuration:

```$bash
sh files/federation/01-mesh3-prerequisites.sh
```

### Install Service Mesh 3

Once the respective certificates have been created in both clusters, it is time to create the service mesh control plane itself and an application to test locally both mesh architecture.

Please execute the following script to perform this configuration:

```$bash
sh files/federation/02-setup-cluster01-tp1.sh
sh files/federation/03-setup-cluster02-tp1.sh
```

### Enable Service Discovery in Multiple Clusters

Finally, it is required to enable a method to federate or discover multiple services in multiples clusters at the same time.

In order to implement this configuration, please execute the following scripts:

```$bash
sh files/federation/04-enable-discovery.sh
sh files/federation/05-create-multicluster-app.sh
```

Once the muticluster app has been created in both clusters, it will be possible to access to services en the different clusters as same as local services in each cluster.

### Enable Observability Stack

Finally, the last step is to install the observability stack in oder to be able to visualize inter applications connections and configuration.

Red Hat OpenShift Observability provides real-time visibility, monitoring, and analysis of various system metrics, logs, and events to help you quickly diagnose and troubleshoot issues before they impact systems or applications.

Red Hat OpenShift Observability connects open-source observability tools and technologies to create a unified Observability solution. The components of Red Hat OpenShift Observability work together to help you collect, store, deliver, analyze, and visualize data.

Red Hat OpenShift Service Mesh integrates with the following Red Hat OpenShift Observability components:

- Metrics using Openshift UDP (User Defined Project integration with Prometheus)
- Tracing using Red Hat OpenShift distributed tracing platform (Tempo) and Red Hat OpenShift distributed tracing data collection.
- Visualization using Kiali Operator provided by Red Hat to view the data flow through your application.

Please execute the following script to perform this configuration:

```$bash

**Modify AWS env vars to include AWS_KEY, AWS_SECRET and S3 buckets names for both clusters:

vi files/federation/06-observability.sh

sh files/federation/06-observability.sh
```

## Links

- https://docs.openshift.com/service-mesh/3.0.0tp1/install/ossm-multi-cluster-topologies.html
- https://istio.io/latest/docs/setup/install/multicluster/multi-primary/
- https://istio.io/latest/docs/setup/install/multicluster/verify/

## Author

Asier Cidon @RedHat
