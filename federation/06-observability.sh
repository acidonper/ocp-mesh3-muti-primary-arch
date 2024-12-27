#!/bin/bash
##
# Script to install Observability in OSSM 3
##

AWS_KEY="XXXX"
AWS_SECRET="XXX"
BUCKET_CLUSTER01="cluster001"
BUCKET_CLUSTER02="cluster02"

## Check Environment variables required 

if [[ "${CTX_CLUSTER1}" == "" || "${CTX_CLUSTER2}" == "" ]]
then
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} is NOT defined"
else
  echo "Cluster 1 Kubectl Context: ${CTX_CLUSTER1} or Cluster 2 Kubectl Context: ${CTX_CLUSTER2} are defined"
fi

## Install Monitoring

cat <<EOF > /tmp/prometheus.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF

cat /tmp/prometheus.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/prometheus.yaml | oc apply --context ${CTX_CLUSTER2} -f -


cat <<EOF > /tmp/servicemonitoristiod-cluster01.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istiod-monitor
  namespace: istio-system-cluster01
spec:
  targetLabels:
  - app
  selector:
    matchLabels:
      istio: pilot
  endpoints:
  - port: http-monitoring
    interval: 30s
EOF
cat <<EOF > /tmp/servicemonitoristiod-cluster02.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istiod-monitor
  namespace: istio-system-cluster02
spec:
  targetLabels:
  - app
  selector:
    matchLabels:
      istio: pilot
  endpoints:
  - port: http-monitoring
    interval: 30s
EOF

cat /tmp/servicemonitoristiod-cluster01.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/servicemonitoristiod-cluster02.yaml | oc apply --context ${CTX_CLUSTER2} -f -

cat <<EOF > /tmp/podmonitorsmesh-cluster01.yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-proxies-monitor
  namespace: istio-system-cluster01
spec:
  selector:
    matchExpressions:
    - key: istio-prometheus-ignore
      operator: DoesNotExist
  podMetricsEndpoints:
  - path: /stats/prometheus
    interval: 30s
    relabelings:
    - action: keep
      sourceLabels: ["__meta_kubernetes_pod_container_name"]
      regex: "istio-proxy"
    - action: keep
      sourceLabels: ["__meta_kubernetes_pod_annotationpresent_prometheus_io_scrape"]
    - action: replace
      regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
      replacement: '[$2]:$1'
      sourceLabels: ["__meta_kubernetes_pod_annotation_prometheus_io_port","__meta_kubernetes_pod_ip"]
      targetLabel: "__address__"
    - action: replace
      regex: (\d+);((([0-9]+?)(\.|$)){4})
      replacement: '$2:$1'
      sourceLabels: ["__meta_kubernetes_pod_annotation_prometheus_io_port","__meta_kubernetes_pod_ip"]
      targetLabel: "__address__"
    - action: labeldrop
      regex: "__meta_kubernetes_pod_label_(.+)"
    - sourceLabels: ["__meta_kubernetes_namespace"]
      action: replace
      targetLabel: namespace
    - sourceLabels: ["__meta_kubernetes_pod_name"]
      action: replace
      targetLabel: pod_name
EOF
cat <<EOF > /tmp/podmonitorsmesh-cluster02.yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-proxies-monitor
  namespace: istio-system-cluster02
spec:
  selector:
    matchExpressions:
    - key: istio-prometheus-ignore
      operator: DoesNotExist
  podMetricsEndpoints:
  - path: /stats/prometheus
    interval: 30s
    relabelings:
    - action: keep
      sourceLabels: ["__meta_kubernetes_pod_container_name"]
      regex: "istio-proxy"
    - action: keep
      sourceLabels: ["__meta_kubernetes_pod_annotationpresent_prometheus_io_scrape"]
    - action: replace
      regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
      replacement: '[$2]:$1'
      sourceLabels: ["__meta_kubernetes_pod_annotation_prometheus_io_port","__meta_kubernetes_pod_ip"]
      targetLabel: "__address__"
    - action: replace
      regex: (\d+);((([0-9]+?)(\.|$)){4})
      replacement: '$2:$1'
      sourceLabels: ["__meta_kubernetes_pod_annotation_prometheus_io_port","__meta_kubernetes_pod_ip"]
      targetLabel: "__address__"
    - action: labeldrop
      regex: "__meta_kubernetes_pod_label_(.+)"
    - sourceLabels: ["__meta_kubernetes_namespace"]
      action: replace
      targetLabel: namespace
    - sourceLabels: ["__meta_kubernetes_pod_name"]
      action: replace
      targetLabel: pod_name
EOF

cat /tmp/podmonitorsmesh-cluster01.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/podmonitorsmesh-cluster02.yaml | oc apply --context ${CTX_CLUSTER2} -f -

sleep 30


## Install Tempo

oc get operators tempo-product.openshift-tempo-operator --context ${CTX_CLUSTER1}
[[ $? -eq 0 ]] || { echo >&2 "It is required to have tempo-product.openshift-tempo-operator operator already installed in Openshift (cluster01)"; exit 1; }

oc get operators tempo-product.openshift-tempo-operator --context ${CTX_CLUSTER2}
[[ $? -eq 0 ]] || { echo >&2 "It is required to have tempo-product.openshift-tempo-operator operator already installed in Openshift (cluster02)"; exit 1; }

cat <<EOF > /tmp/awssecret-cluster01.yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-secret
  namespace: istio-system-cluster01
stringData:
  endpoint: https://s3.eu-west-1.amazonaws.com
  bucket: ${BUCKET_CLUSTER01}
  access_key_id: ${AWS_KEY}
  access_key_secret: ${AWS_SECRET}
type: Opaque
EOF
cat <<EOF > /tmp/awssecret-cluster02.yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-secret
  namespace: istio-system-cluster02
stringData:
  endpoint: https://s3.eu-west-1.amazonaws.com
  bucket: ${BUCKET_CLUSTER02}
  access_key_id: ${AWS_KEY}
  access_key_secret: ${AWS_SECRET}
type: Opaque
EOF

cat /tmp/awssecret-cluster01.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/awssecret-cluster02.yaml | oc apply --context ${CTX_CLUSTER2} -f -


cat <<EOF > /tmp/tempo-cluster01.yaml
apiVersion: tempo.grafana.com/v1alpha1
kind: TempoStack
metadata:
  name: simplest
  namespace: istio-system-cluster01
spec:
  storageSize: 1Gi
  storage: 
    secret:
      name: aws-secret
      type: s3
  resources:
    total:
      limits:
        memory: 2Gi
        cpu: 2000m
  template:
    queryFrontend:
      jaegerQuery: 
        enabled: true
        ingress:
          route:
            termination: edge
          type: route
EOF
cat <<EOF > /tmp/tempo-cluster02.yaml
apiVersion: tempo.grafana.com/v1alpha1
kind: TempoStack
metadata:
  name: simplest
  namespace: istio-system-cluster02
spec:
  storageSize: 1Gi
  storage: 
    secret:
      name: aws-secret
      type: s3
  resources:
    total:
      limits:
        memory: 2Gi
        cpu: 2000m
  template:
    queryFrontend:
      jaegerQuery: 
        enabled: true
        ingress:
          route:
            termination: edge
          type: route
EOF

cat /tmp/tempo-cluster01.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/tempo-cluster02.yaml | oc apply --context ${CTX_CLUSTER2} -f -

sleep 30

## Install Distributed tracing

oc get operators jaeger-product.openshift-distributed-tracing --context ${CTX_CLUSTER1}
[[ $? -eq 0 ]] || { echo >&2 "It is required to have jaeger-product.openshift-distributed-tracing already installed in Openshift (cluster01)"; exit 1; }

oc get operators jaeger-product.openshift-distributed-tracing --context ${CTX_CLUSTER2}
[[ $? -eq 0 ]] || { echo >&2 "It is required to have jaeger-product.openshift-distributed-tracing operator already installed in Openshift (cluster02)"; exit 1; }

oc get operators opentelemetry-product.openshift-opentelemetry-operator --context ${CTX_CLUSTER1}
[[ $? -eq 0 ]] || { echo >&2 "It is required to have opentelemetry-product.openshift-opentelemetry-operator already installed in Openshift (cluster01)"; exit 1; }

oc get operators opentelemetry-product.openshift-opentelemetry-operator --context ${CTX_CLUSTER2}
[[ $? -eq 0 ]] || { echo >&2 "It is required to have opentelemetry-product.openshift-opentelemetry-operator already installed in Openshift (cluster02)"; exit 1; }

cat <<EOF > /tmp/telemetry-cluster01.yaml
kind: OpenTelemetryCollector
apiVersion: opentelemetry.io/v1beta1
metadata:
  name: otel
  namespace: istio-system-cluster01
spec:
  observability:
    metrics: {}
  deploymentUpdateStrategy: {}
  config:
    exporters:
      otlp:
        endpoint: 'tempo-simplest-distributor.istio-system-cluster01.svc.cluster.local:4317'
        tls:
          insecure: true
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: '0.0.0.0:4317'
          http: {}
    service:
      pipelines:
        traces:
          exporters:
            - otlp
          receivers:
            - otlp
EOF
cat <<EOF > /tmp/telemetry-cluster02.yaml
kind: OpenTelemetryCollector
apiVersion: opentelemetry.io/v1beta1
metadata:
  name: otel
  namespace: istio-system-cluster02
spec:
  observability:
    metrics: {}
  deploymentUpdateStrategy: {}
  config:
    exporters:
      otlp:
        endpoint: 'tempo-simplest-distributor.istio-system-cluster02.svc.cluster.local:4317'
        tls:
          insecure: true
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: '0.0.0.0:4317'
          http: {}
    service:
      pipelines:
        traces:
          exporters:
            - otlp
          receivers:
            - otlp
EOF

cat /tmp/telemetry-cluster01.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/telemetry-cluster02.yaml | oc apply --context ${CTX_CLUSTER2} -f -

cat <<EOF > /tmp/patch-cluster01.yaml
spec:
  values:
    meshConfig:
      enableTracing: true
      extensionProviders:
      - name: otel-tracing
        opentelemetry:
          port: 4317
          service: otel-collector.istio-system-cluster01.svc.cluster.local
EOF
cat <<EOF > /tmp/patch-cluster02.yaml
spec:
  values:
    meshConfig:
      enableTracing: true
      extensionProviders:
      - name: otel-tracing
        opentelemetry:
          port: 4317
          service: otel-collector.istio-system-cluster02.svc.cluster.local
EOF

oc patch istio istio-system-cluster01 --type merge --patch-file /tmp/patch-cluster01.yaml --context ${CTX_CLUSTER1}
oc patch istio istio-system-cluster02 --type merge --patch-file /tmp/patch-cluster02.yaml --context ${CTX_CLUSTER2}

cat <<EOF > /tmp/tel-cluster01.yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: otel-demo
  namespace: istio-system-cluster01
spec:
  tracing:
    - providers:
        - name: otel-tracing
      randomSamplingPercentage: 100
EOF
cat <<EOF > /tmp/tel-cluster02.yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: otel-demo
  namespace: istio-system-cluster02
spec:
  tracing:
    - providers:
        - name: otel-tracing
      randomSamplingPercentage: 100
EOF

cat /tmp/tel-cluster01.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/tel-cluster02.yaml | oc apply --context ${CTX_CLUSTER2} -f -

## Install Kiali

oc get operators kiali-ossm.openshift-operators --context ${CTX_CLUSTER1}
[[ $? -eq 0 ]] || { echo >&2 "It is required to have kiali-ossm.openshift-operators operator already installed in Openshift (cluster01)"; exit 1; }

oc get operators kiali-ossm.openshift-operators --context ${CTX_CLUSTER2}
[[ $? -eq 0 ]] || { echo >&2 "It is required to have kiali-ossm.openshift-operators operator already installed in Openshift (cluster02)"; exit 1; }

cat <<EOF > /tmp/rolebindingkiali.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kiali-monitoring-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-monitoring-view
subjects:
- kind: ServiceAccount
  name: kiali-service-account
  namespace: istio-system
EOF

cat /tmp/rolebindingkiali.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/rolebindingkiali.yaml | oc apply --context ${CTX_CLUSTER2} -f -


cat <<EOF > /tmp/kiali-cluster01.yaml
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali-user-workload-monitoring
  namespace: istio-system-cluster01
spec:
  external_services:
    prometheus:
      auth:
        type: bearer
        use_kiali_token: true
      thanos_proxy:
        enabled: true
      url: https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
EOF
cat <<EOF > /tmp/kiali-cluster02.yaml
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali-user-workload-monitoring
  namespace: istio-system-cluster02
spec:
  external_services:
    prometheus:
      auth:
        type: bearer
        use_kiali_token: true
      thanos_proxy:
        enabled: true
      url: https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
EOF

cat /tmp/kiali-cluster01.yaml | oc apply --context ${CTX_CLUSTER1} -f -
cat /tmp/kiali-cluster02.yaml | oc apply --context ${CTX_CLUSTER2} -f -

sleep 30

echo "https://$(oc get routes -n istio-system-cluster01 kiali -o jsonpath='{.spec.host}' --context ${CTX_CLUSTER1})"
echo "https://$(oc get routes -n istio-system-cluster02 kiali -o jsonpath='{.spec.host}' --context ${CTX_CLUSTER2})"