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

### 4. Create cluster. 
The king-config.yaml file creates a kind cluster with 3 worker nodes and 1 control plane node.
```shell
kind create cluster --config=./kind-config.yaml
```

### 5. Install ingress (nginx)
```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```
Wait until is ready to process requests running:
```shell
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### 6. Install Prometheus
```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus
```
// helm install prometheus oci://registry-1.docker.io/bitnamicharts/prometheus

### 7. Install Grafana
```shell
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana
```

### 8. Install Kafka
```shell
helm install kafka oci://registry-1.docker.io/bitnamicharts/kafka
```

### 9. Install Kafka UI
```shell
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm repo update
helm install kafka-ui kafka-ui/kafka-ui
```
**Note:** more information in https://docs.kafka-ui.provectus.io/configuration/helm-charts/quick-start

It's needed to update kafka-ui chart configuration to connect it to kafka. 
So, From Lens you must go to kind-kind > Helm > Releases, click on kafka-ui line and a popu-up will appear.
In this popup, there is a text area named 'Value' which has a json inside. You update the json adding the following lines:
```yaml
yamlApplicationConfig:
  auth:
    type: disabled
  kafka:
    clusters:
    - bootstrapServers: kafka.default.svc.cluster.local:9092
      name: k8s-kafka
      properties:
        sasl.jaas.config: org.apache.kafka.common.security.scram.ScramLoginModule required username="user1" password="xxxxx";
        sasl.mechanism: PLAIN
        security.protocol: SASL_PLAINTEXT
  management:
    health:
      ldap:
        enabled: false
```
Kafka password can be gotten if you run the following command
```shell
kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1
```
When you did all changes, you must press 'Save' button. This action will restart the kafka-ui pod, and when the pod comes back to live, it will be connected to kafka cluster.  

### 10. Create topic (optional)

It's a good idea to create topics before ecomm app starts, because you will be able to define partitions and replication factor for each.
In case that topics are not created, app will create them with partition and replication factor of 1.
If you create a port forwarding from Lens or using this commands:
```shell
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=kafka-ui,app.kubernetes.io/instance=kafka-ui" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 8080:8080
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

### 11. Install ecomm

```shell
helm install ecomm-monitoring ./../k8s/10-monitoring --namespace ecomm-kind --create-namespace -f ./../k8s/10-monitoring/kind.yaml
helm install ecomm-users ./../k8s/20-users --namespace ecomm-kind --create-namespace -f ./../k8s/20-users/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-products ./../k8s/30-products --namespace ecomm-kind --create-namespace -f ./../k8s/30-products/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-orders ./../k8s/40-orders --namespace ecomm-kind --create-namespace -f ./../k8s/40-orders/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-admin-bff ./../k8s/50-admin-bff --namespace ecomm-kind --create-namespace -f ./../k8s/50-admin-bff/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-limiter-processor ./../k8s/60-limiter-processor --namespace ecomm-kind --create-namespace -f ./../k8s/60-limiter-processor/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-limiter-kafka-mps ./../k8s/70-limiter-kafka-mps --namespace ecomm-kind --create-namespace -f ./../k8s/70-limiter-kafka-mps/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-gateway-admin-bff ./../k8s/80-gateway-admin-bff --namespace ecomm-kind --create-namespace -f ./../k8s/80-gateway-admin-bff/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
```

## Uninstallation

### 1. Uninstall ecomm

```shell
helm uninstall --namespace ecomm-kind ecomm-gateway-admin-bff
helm uninstall --namespace ecomm-kind ecomm-limiter-kafka-mps
helm uninstall --namespace ecomm-kind ecomm-limiter-processor
helm uninstall --namespace ecomm-kind ecomm-admin-bff
helm uninstall --namespace ecomm-kind ecomm-orders
helm uninstall --namespace ecomm-kind ecomm-products
helm uninstall --namespace ecomm-kind ecomm-users
helm uninstall --namespace ecomm-kind ecomm-monitoring
```

### 2. Uninstall all tools

```shell
helm uninstall kafka-ui
helm uninstall kafka
helm uninstall grafana
helm uninstall prometheus
```

### 3. Delete kind cluster
```shell
kind delete cluster
```

---

## Access to tools in cluster

### 1. Prometheus

The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
```text
prometheus-server.default.svc.cluster.local
```

Get the Prometheus server URL by running these commands in the same shell:
```shell
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9090
```
you will be able to reach prometheus on http://127.0.0.1:9090

The Prometheus alertmanager can be accessed via port 9093 on the following DNS name from within your cluster:
```text
prometheus-alertmanager.default.svc.cluster.local
```

Get the Alertmanager URL by running these commands in the same shell:
```shell
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9093
```
you will be able to reach prometheus alertmanager on http://127.0.0.1:9093

The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
```text
prometheus-prometheus-pushgateway.default.svc.cluster.local
```

Get the PushGateway URL by running these commands in the same shell:
```shell
export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9091
```
you will be able to reach prometheus push gateway on http://127.0.0.1:9091

**Note:** If you need more information about prometheus: https://semaphoreci.com/blog/prometheus-grafana-kubernetes-helm and https://prometheus.io/


### 2. Grafana

Get your 'admin' user password by running:
```shell
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:
```text
grafana.default.svc.cluster.local
```

Get the Grafana URL to visit by running these commands in the same shell:
```shell
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 3000
```
you will be able to reach grafana on http://127.0.0.1:3000

Login with the password from step 1 and the username: admin


### 3. Kafka UI

Get the application URL by running these commands:
```shell
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=kafka-ui,app.kubernetes.io/instance=kafka-ui" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 8080:8080
```
you will be able to reach kafka ui on http://127.0.0.1:8080


### 4. Kafka

Kafka can be accessed by consumers via port 9092 on the following DNS name from within your cluster:
```text
kafka.default.svc.cluster.local
```
Each Kafka broker can be accessed by producers via port 9092 on the following DNS name(s) from within your cluster:
```text
kafka-controller-0.kafka-controller-headless.default.svc.cluster.local:9092
kafka-controller-1.kafka-controller-headless.default.svc.cluster.local:9092
kafka-controller-2.kafka-controller-headless.default.svc.cluster.local:9092
```

The CLIENT listener for Kafka client connections from within your cluster have been configured with the following security settings:
- SASL authentication

To connect a client to your Kafka, you need to create the 'client.properties' configuration files with the content below:

security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="user1" \
password="$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)";

To create a pod that you can use as a Kafka client run the following commands:

    kubectl run kafka-client --restart='Never' --image docker.io/bitnami/kafka:3.8.0-debian-12-r5 --namespace default --command -- sleep infinity
    kubectl cp --namespace default /path/to/client.properties kafka-client:/tmp/client.properties
    kubectl exec --tty -i kafka-client --namespace default -- bash

    PRODUCER:
        kafka-console-producer.sh \
            --producer.config /tmp/client.properties \
            --bootstrap-server kafka.default.svc.cluster.local:9092 \
            --topic test

    CONSUMER:
        kafka-console-consumer.sh \
            --consumer.config /tmp/client.properties \
            --bootstrap-server kafka.default.svc.cluster.local:9092 \
            --topic test \
            --from-beginning

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
- controller.resources
  +info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/













sergio@Alienware-x15-R2 ~/dev/projects/e-commerce/deploy/kind  (main)$ helm install prometheus prometheus-community/prometheus
NAME: prometheus
LAST DEPLOYED: Tue Oct 22 12:45:01 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
prometheus-server.default.svc.cluster.local


Get the Prometheus server URL by running these commands in the same shell:
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9090


The Prometheus alertmanager can be accessed via port 9093 on the following DNS name from within your cluster:
prometheus-alertmanager.default.svc.cluster.local


Get the Alertmanager URL by running these commands in the same shell:
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9093
#################################################################################
######   WARNING: Pod Security Policy has been disabled by default since    #####
######            it deprecated after k8s 1.25+. use                        #####
######            (index .Values "prometheus-node-exporter" "rbac"          #####
###### .          "pspEnabled") with (index .Values                         #####
######            "prometheus-node-exporter" "rbac" "pspAnnotations")       #####
######            in case you still need it.                                #####
#################################################################################


The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
prometheus-prometheus-pushgateway.default.svc.cluster.local


Get the PushGateway URL by running these commands in the same shell:
export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9091

For more information on running Prometheus, visit:
https://prometheus.io/








sergio@Alienware-x15-R2 ~/dev/projects/e-commerce/deploy/kind  (main)$ helm install grafana grafana/grafana

NAME: grafana
LAST DEPLOYED: Tue Oct 22 12:45:09 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
1. Get your 'admin' user password by running:

   kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


2. The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:

   grafana.default.svc.cluster.local

   Get the Grafana URL to visit by running these commands in the same shell:
   export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
   kubectl --namespace default port-forward $POD_NAME 3000

3. Login with the password from step 1 and the username: admin
   #################################################################################
######   WARNING: Persistence is disabled!!! You will lose your data when   #####
######            the Grafana pod is terminated.                            #####
#################################################################################



sergio@Alienware-x15-R2 ~/dev/projects/e-commerce/deploy/kind  (main)$
sergio@Alienware-x15-R2 ~/dev/projects/e-commerce/deploy/kind  (main)$ helm install kafka oci://registry-1.docker.io/bitnamicharts/kafka
Pulled: registry-1.docker.io/bitnamicharts/kafka:30.1.6
Digest: sha256:652c63d81a1683a117d8b1a88b33d4d3ee3fc302960b886c0a56c01ae25e7d11
NAME: kafka
LAST DEPLOYED: Tue Oct 22 12:45:20 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
CHART NAME: kafka
CHART VERSION: 30.1.6
APP VERSION: 3.8.0

** Please be patient while the chart is being deployed **

Kafka can be accessed by consumers via port 9092 on the following DNS name from within your cluster:

    kafka.default.svc.cluster.local

Each Kafka broker can be accessed by producers via port 9092 on the following DNS name(s) from within your cluster:

    kafka-controller-0.kafka-controller-headless.default.svc.cluster.local:9092
    kafka-controller-1.kafka-controller-headless.default.svc.cluster.local:9092
    kafka-controller-2.kafka-controller-headless.default.svc.cluster.local:9092

The CLIENT listener for Kafka client connections from within your cluster have been configured with the following security settings:
- SASL authentication

To connect a client to your Kafka, you need to create the 'client.properties' configuration files with the content below:

security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="user1" \
password="$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)";

To create a pod that you can use as a Kafka client run the following commands:

    kubectl run kafka-client --restart='Never' --image docker.io/bitnami/kafka:3.8.0-debian-12-r5 --namespace default --command -- sleep infinity
    kubectl cp --namespace default /path/to/client.properties kafka-client:/tmp/client.properties
    kubectl exec --tty -i kafka-client --namespace default -- bash

    PRODUCER:
        kafka-console-producer.sh \
            --producer.config /tmp/client.properties \
            --bootstrap-server kafka.default.svc.cluster.local:9092 \
            --topic test

    CONSUMER:
        kafka-console-consumer.sh \
            --consumer.config /tmp/client.properties \
            --bootstrap-server kafka.default.svc.cluster.local:9092 \
            --topic test \
            --from-beginning

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
- controller.resources
  +info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/


sergio@Alienware-x15-R2 ~/dev/projects/e-commerce/deploy/kind  (main)$ helm install kafka-ui kafka-ui/kafka-ui

NAME: kafka-ui
LAST DEPLOYED: Wed Oct 23 00:48:01 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
1. Get the application URL by running these commands:
   export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=kafka-ui,app.kubernetes.io/instance=kafka-ui" -o jsonpath="{.items[0].metadata.name}")
   echo "Visit http://127.0.0.1:8080 to use your application"
   kubectl --namespace default port-forward $POD_NAME 8080:8080
