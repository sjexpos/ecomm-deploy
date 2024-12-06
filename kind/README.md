# Kind deployment

This folder contains instructions to deploy ecomm services to [Kind](https://kind.sigs.k8s.io/) kubernetes.

## Requirements

* [Docker](https://www.docker.com/)
* [Go lang 1.16+](https://go.dev/dl/)
* [kubectl](https://kubernetes.io/es/docs/reference/kubectl/)
* [Helm](https://helm.sh/)
* [Kind 0.24.0](https://github.com/kubernetes-sigs/kind/)
* [Lens desktop](https://k8slens.dev/) or [OpenLens]()

## Installation

### 1. Install Go lang from https://go.dev/dl/ and add go bin folder in your PATH environment variable
```shell
export PATH=<GO_HOME_DIR>/bin:$PATH
```

### 2. Install Kind from https://github.com/kubernetes-sigs/kind/
```shell
go install sigs.k8s.io/kind@v0.24.0
```

### 3. Add go bin to PATH
```shell
export PATH=<GO_BIN_DIR>:$PATH
```
Go download and install packages and bin in a folder which is defined in `go env GOPATH`. In linux by default is $HOME/go. So path will be: `export PATH=$HOME/go/bin:$PATH`

### 4. Increase max open files

Because of some pods can show “too many open files”, it is needed to increase max open files.
Resource limits are defined by fs.inotify.max_user_watches and fs.inotify.max_user_instances system variables. For example, in Ubuntu these default to 8192 and 128 respectively, which is not enough to create a cluster with many nodes.

To increase these limits temporarily run the following commands on the host:
```shell
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512
```
To make the changes persistent, edit the file /etc/sysctl.conf and add these lines:
```text
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
```

### 5. Start up external services

Some pods need external services like postgres, redis and elasticsearch, it is possible to run them using docker compose on folder `../compose`.
On this folder you must run:
```shell
docker compose --profile kind up
```

### 6. Create cluster. 
The king-config.yaml file creates a kind cluster with 3 worker nodes and 1 control plane node.
```shell
kind create cluster --config=./kind-config.yaml
```

### 7. Install metrics server

They are needed to Horizontal Auto Scaling

```shell
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm install metrics-server -n monitoring metrics-server/metrics-server --create-namespace -f ./metrics-server.yaml
```
**Note**: the file metrics-server.yaml was download from https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml and it was added a new argument `--kubelet-insecure-tls=true`

Wait until is ready to process requests running:
```shell
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=metrics-server --timeout=90s
```

You can check if metrics servers are running:
```shell
kubectl get apiservices | grep metrics
```
You will see:
```text
NAME                         SERVICE                      AVAILABLE                       AGE
v1beta1.metrics.k8s.io       kube-system/metrics-server   True                            42m
```

To get the stats about your resources, you just need to run these commands. To monitor the resources of your nodes:
```shell
kubectl top nodes
```

To monitor the resource of your pods:
```shell
kubectl top pods
```

Then verify the result state (after a minute or so):
```shell
kubectl get hpa -n ecomm-kind --watch
```

### 8. Install ingress (nginx)
```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```
Wait until is ready to process requests running:
```shell
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
```

### 9. Install Prometheus, Loki, and Grafana to monitor

#### Install prometheus with kubernetes metrics, operator and alerts:
```shell
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install prometheus bitnami/kube-prometheus -n monitoring --create-namespace --set prometheus.enableFeatures={otlp-write-receiver}
```
Wait until is ready to process requests running:
```shell
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=prometheus --timeout=90s
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/component=prometheus --timeout=90s
```

You can also create a port forwarding to the service `prometheus-kube-prometheus-prometheus` on its port 9090 if you want to see prometheus dashboard (mainly to check targets).
#### Install grafana
```shell
helm install grafana bitnami/grafana -n monitoring --create-namespace
```
Wait until is ready to process requests running:
```shell
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/component=grafana --timeout=90s
```
When all pods are running, you can create a port forwarding to the service `grafana` on its port 3000.
Credentials:
   echo "User: admin"
   echo "Password: $(kubectl get secret grafana-admin --namespace monitoring -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 -d)"

You must sign-in grafana using credentials above and create a data source. You pick-up `prometheus` and use `http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090` as connection url. Click Save & test.

#### Install loki
```shell
helm install loki bitnami/grafana-loki -n monitoring --create-namespace
```
Wait until is ready to process requests running:
```shell
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=loki --timeout=90s
```

#### Configure Loki with Grafana.
Go to Grafana dashboard and Home > Connections > Datasources then click on Add new data source.
Search for Loki and configure it like:
```text
HTTP: http://loki-grafana-loki-query-frontend.monitoring.svc.cluster.local:3100
Allowed cookies: <empty>
Timeout: <empty>
```
**Note**: You only need to add the URL of Loki for this project. “monitoring” is the namespace which loki is installed.

Then click on Save and Test.

#### Load Loki dashboard.
You can import a Loki dashboard to see services logs. A good option is https://grafana.com/grafana/dashboards/16966-container-log-dashboard/. You are able to import it using the ID 16966.

#### Load interesting dashboards

Grafana.com dashboard id list:

| Dashboard                          | ID    | URL                                                                                   |
|:-----------------------------------|:------|:--------------------------------------------------------------------------------------|
| k8s-addons-prometheus.json         | 19105 | https://grafana.com/grafana/dashboards/19105-prometheus/                              |
| k8s-addons-trivy-operator.json     | 16337 | https://grafana.com/grafana/dashboards/16337-trivy-operator-vulnerabilities/          |
| k8s-system-api-server.json         | 15761 | https://grafana.com/grafana/dashboards/15761-kubernetes-system-api-server/            |
| k8s-system-coredns.json            | 15762 | https://grafana.com/grafana/dashboards/15762-kubernetes-system-coredns/               |
| k8s-views-global.json              | 15757 | https://grafana.com/grafana/dashboards/15757-kubernetes-views-global/                 |
| k8s-views-namespaces.json          | 15758 | https://grafana.com/grafana/dashboards/15758-kubernetes-views-namespaces/             |
| k8s-views-nodes.json               | 15759 | https://grafana.com/grafana/dashboards/15759-kubernetes-views-nodes/                  |
| k8s-views-pods.json                | 15760 | https://grafana.com/grafana/dashboards/15760-kubernetes-views-pods/                   |
|                                    | 15661 | https://grafana.com/grafana/dashboards/15661-1-k8s-for-prometheus-dashboard-20211010/ |
|                                    | 19004 | https://grafana.com/grafana/dashboards/19004-spring-boot-statistics/                  |
|                                    | 16966 | https://grafana.com/grafana/dashboards/16966-container-log-dashboard/                 |


### 10. Install Jaeger

```shell
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
helm install jaeger -n monitoring jaegertracing/jaeger --create-namespace -f ./jaeger-values.yaml
```
Wait until is ready to process requests running:
```shell
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=jaeger --timeout=90s
```

### 11. Install OpenTelemetry collector

```shell
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm install otel-collector -n monitoring open-telemetry/opentelemetry-collector --create-namespace -f ./otel-collector-values.yaml
```

### 12. Install Kafka
```shell
helm install kafka oci://registry-1.docker.io/bitnamicharts/kafka -n infra --create-namespace
```
Wait until is ready to process requests running:
```shell
kubectl wait --namespace infra --for=condition=ready pod --selector=app.kubernetes.io/instance=kafka --timeout=90s
```

Kafka password can be gotten if you run the following command
```shell
kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1
```

### 13. Install Kafka UI
```shell
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm repo update
KAFKA_PASSWORD=`kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1` bash -c 'sed "s/PASSWORD/"$KAFKA_PASSWORD"/g" ./kafka-ui.yaml | helm install kafka-ui kafka-ui/kafka-ui -n infra --create-namespace -f - '
```
**Note:** more information in https://docs.kafka-ui.provectus.io/configuration/helm-charts/quick-start
Wait until is ready to process requests running:
```shell
kubectl wait --namespace infra --for=condition=ready pod --selector=app.kubernetes.io/instance=kafka-ui --timeout=90s
```

### 14. Create topic (optional)

It's a good idea to create topics before ecomm app starts, because you will be able to define partitions and replication factor for each.
In case that topics are not created, app will create them with partition and replication factor of 1.
If you create a port forwarding from Lens or using this commands:
```shell
export POD_NAME=$(kubectl get pods --namespace infra -l "app.kubernetes.io/name=kafka-ui,app.kubernetes.io/instance=kafka-ui" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace infra port-forward $POD_NAME 8080:8080
```
you will be able to reach kafka-ui on http://127.0.0.1:8080

Create following topics:

- incoming-request-topic
  partitions: 100
  replication-factor: 2
- request-dlq
  partitions: 1
  replication-factor: 2
- blacklisted-users-topic
  partitions: 10
  replication-factor: 2

### 15. Install KEDA

```shell
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda -n keda kedacore/keda --create-namespace
```

### 15. Install ecomm

```shell
helm install ecomm-monitoring ./../k8s/10-monitoring --namespace ecomm-kind --create-namespace -f ./../k8s/10-monitoring/kind.yaml
helm install ecomm-users ./../k8s/20-users --namespace ecomm-kind --create-namespace -f ./../k8s/20-users/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-products ./../k8s/30-products --namespace ecomm-kind --create-namespace -f ./../k8s/30-products/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-orders ./../k8s/40-orders --namespace ecomm-kind --create-namespace -f ./../k8s/40-orders/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-limiter-processor ./../k8s/60-limiter-processor --namespace ecomm-kind --create-namespace -f ./../k8s/60-limiter-processor/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-limiter-kafka-mps ./../k8s/70-limiter-kafka-mps --namespace ecomm-kind --create-namespace -f ./../k8s/70-limiter-kafka-mps/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-admin-bff ./../k8s/50-admin-bff --namespace ecomm-kind --create-namespace -f ./../k8s/50-admin-bff/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-gateway-admin-bff ./../k8s/80-gateway-admin-bff --namespace ecomm-kind --create-namespace -f ./../k8s/80-gateway-admin-bff/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
```

### 16. Useful commands 

Monitoring HPA
```shell
kubectl -n ecomm-kind get hpa --watch
```
Monitoring deployment events
```shell
kubectl -n ecomm-kind describe deploy users-service
```
Increase the load
```shell
kubectl run -n ecomm-kind -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://users-service:8000/api; done"
```

```shell
kubectl -n ecomm-kind get scaledobject.keda.sh/prometheus-scaledobject
kubectl -n ecomm-kind get hpa
```

## Uninstallation

### 1. Uninstall ecomm

```shell
helm uninstall --namespace ecomm-kind ecomm-gateway-admin-bff
helm uninstall --namespace ecomm-kind ecomm-admin-bff
helm uninstall --namespace ecomm-kind ecomm-limiter-kafka-mps
helm uninstall --namespace ecomm-kind ecomm-limiter-processor
helm uninstall --namespace ecomm-kind ecomm-orders
helm uninstall --namespace ecomm-kind ecomm-products
helm uninstall --namespace ecomm-kind ecomm-users
helm uninstall --namespace ecomm-kind ecomm-monitoring
```

### 2. Uninstall all tools

```shell
helm uninstall --namespace keda keda
helm uninstall --namespace infra kafka-ui
helm uninstall --namespace infra kafka
helm uninstall --namespace monitoring otel-collector
helm uninstall --namespace monitoring jaeger
helm uninstall --namespace monitoring loki
helm uninstall --namespace monitoring grafana
helm uninstall --namespace monitoring prometheus
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
helm uninstall --namespace monitoring metrics-server 
```

### 3. Delete kind cluster
```shell
kind delete cluster
```

---

## Access to tools in cluster

### 1. Kafka UI

Get the application URL by running these commands:
```shell
export POD_NAME=$(kubectl get pods --namespace infra -l "app.kubernetes.io/name=kafka-ui,app.kubernetes.io/instance=kafka-ui" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace infra port-forward $POD_NAME 8080:8080
```
you will be able to reach kafka ui on http://127.0.0.1:8080


### 2. Kafka

Kafka can be accessed by consumers via port 9092 on the following DNS name from within your cluster:
```text
kafka.infra.svc.cluster.local
```
Each Kafka broker can be accessed by producers via port 9092 on the following DNS name(s) from within your cluster:
```text
kafka-controller-0.kafka-controller-headless.infra.svc.cluster.local:9092
kafka-controller-1.kafka-controller-headless.infra.svc.cluster.local:9092
kafka-controller-2.kafka-controller-headless.infra.svc.cluster.local:9092
```

The CLIENT listener for Kafka client connections from within your cluster have been configured with the following security settings:
- SASL authentication

To connect a client to your Kafka, you need to create the 'client.properties' configuration files with the content below:

security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="user1" \
password="$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)";

To create a pod that you can use as a Kafka client run the following commands:

    kubectl run kafka-client --restart='Never' --image docker.io/bitnami/kafka:3.8.0-debian-12-r5 --namespace infra --command -- sleep infinity
    kubectl cp --namespace infra /path/to/client.properties kafka-client:/tmp/client.properties
    kubectl exec --tty -i kafka-client --namespace infra -- bash

    PRODUCER:
        kafka-console-producer.sh \
            --producer.config /tmp/client.properties \
            --bootstrap-server kafka.infra.svc.cluster.local:9092 \
            --topic test

    CONSUMER:
        kafka-console-consumer.sh \
            --consumer.config /tmp/client.properties \
            --bootstrap-server kafka.infra.svc.cluster.local:9092 \
            --topic test \
            --from-beginning

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
- controller.resources
  +info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/


