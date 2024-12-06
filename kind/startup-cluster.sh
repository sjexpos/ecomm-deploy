#!/bin/bash

# Creating cluster
kind create cluster --config=./kind-config.yaml

# Installing server metrics
helm install metrics-server -n monitoring metrics-server/metrics-server --create-namespace -f ./metrics-server.yaml > /dev/null
echo "Waiting for metrics server ..."
sleep 2s
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=metrics-server --timeout=300s

# Installing ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml > /dev/null
echo "Waiting for Ingress ..."
sleep 2s
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s

# Installing prometheus
helm install prometheus bitnami/kube-prometheus -n monitoring --create-namespace > /dev/null
echo "Waiting for Prometheus ..."
sleep 2s
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=prometheus --timeout=300s
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/component=prometheus --timeout=300s

# Installing grafana
helm install grafana bitnami/grafana -n monitoring --create-namespace > /dev/null
echo "Waiting for Grafana ..."
sleep 2s
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/component=grafana --timeout=300s

# Installing loki
helm install loki bitnami/grafana-loki -n monitoring --create-namespace > /dev/null
echo "Waiting for Loki ..."
sleep 2s
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=loki --timeout=300s

# Installing Jaeger
helm install jaeger -n monitoring jaegertracing/jaeger --create-namespace -f ./jaeger-values.yaml > /dev/null
echo "Waiting for Jaeger ..."
sleep 2s
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=jaeger --timeout=300s

# Installing Open Telemetry Collector
helm install otel-collector -n monitoring open-telemetry/opentelemetry-collector --create-namespace -f ./otel-collector-values.yaml > /dev/null
echo "Waiting for otel-collector ..."
sleep 2s
kubectl wait --namespace monitoring --for=condition=ready pod --selector=app.kubernetes.io/instance=otel-collector --timeout=300s

# Installing Kafka
helm install kafka oci://registry-1.docker.io/bitnamicharts/kafka -n infra --create-namespace > /dev/null
echo "Waiting for Kafka ..."
sleep 2s
kubectl wait --namespace infra --for=condition=ready pod --selector=app.kubernetes.io/instance=kafka --timeout=300s

# Installing Kafka UI
KAFKA_PASSWORD=`kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1` bash -c 'sed "s/PASSWORD/"$KAFKA_PASSWORD"/g" ./kafka-ui.yaml | helm install kafka-ui kafka-ui/kafka-ui -n infra --create-namespace -f - '  > /dev/null
echo "Waiting for Kafka UI ..."
sleep 2s
kubectl wait --namespace infra --for=condition=ready pod --selector=app.kubernetes.io/instance=kafka-ui --timeout=300s

export KAFKA_PASSWORD=`kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1`

echo "kakfa_user: user1"
echo "kafka_password: $KAFKA_PASSWORD"

# Creating topic "incoming-request-topic"
kubectl run -n infra -i --tty create-incoming-request-topic --rm --image=bitnami/kafka:latest --restart=Never --env="KAFKA_PASSWORD=$KAFKA_PASSWORD" -- /bin/sh -c \
  "echo 'security.protocol=SASL_PLAINTEXT' >> /tmp/client-config.properties && echo 'sasl.mechanism=PLAIN' >> /tmp/client-config.properties && echo 'sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=\"user1\" password=\"$KAFKA_PASSWORD\";' >> /tmp/client-config.properties && cat /tmp/client-config.properties && kafka-topics.sh --command-config /tmp/client-config.properties --create --topic incoming-request-topic --bootstrap-server kafka.infra.svc.cluster.local:9092 --partitions 100 --replication-factor 2"

# Creating topic "request-dlq"
kubectl run -n infra -i --tty create-request-dlq --rm --image=bitnami/kafka:latest --restart=Never --env="KAFKA_PASSWORD=$KAFKA_PASSWORD" -- /bin/sh -c \
  "echo 'security.protocol=SASL_PLAINTEXT' >> /tmp/client-config.properties && echo 'sasl.mechanism=PLAIN' >> /tmp/client-config.properties && echo 'sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=\"user1\" password=\"$KAFKA_PASSWORD\";' >> /tmp/client-config.properties && cat /tmp/client-config.properties && kafka-topics.sh --command-config /tmp/client-config.properties --create --topic request-dlq --bootstrap-server kafka.infra.svc.cluster.local:9092 --partitions 1 --replication-factor 2"

# Creating topic "blacklisted-users-topic"
kubectl run -n infra -i --tty create-blacklisted-users-topic --rm --image=bitnami/kafka:latest --restart=Never --env="KAFKA_PASSWORD=$KAFKA_PASSWORD" -- /bin/sh -c \
  "echo 'security.protocol=SASL_PLAINTEXT' >> /tmp/client-config.properties && echo 'sasl.mechanism=PLAIN' >> /tmp/client-config.properties && echo 'sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=\"user1\" password=\"$KAFKA_PASSWORD\";' >> /tmp/client-config.properties && cat /tmp/client-config.properties && kafka-topics.sh --command-config /tmp/client-config.properties --create --topic blacklisted-users-topic --bootstrap-server kafka.infra.svc.cluster.local:9092 --partitions 10 --replication-factor 2"

# Installing KEDA
helm install keda kedacore/keda -n keda --create-namespace > /dev/null
echo "Waiting for KEDA ..."
sleep 2s
kubectl wait --namespace keda --for=condition=ready pod --selector=app=keda-operator --timeout=300s

echo ""
echo "======================================================"
echo "It's ready to deploy ecomm services!!!"
echo "======================================================"

POD_NAME=$(kubectl get pods --namespace infra -l "app.kubernetes.io/name=kafka-ui,app.kubernetes.io/instance=kafka-ui" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace infra port-forward $POD_NAME 8080:8080 &
KAFKA_UI_PID=$!

POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus-kube-prometheus-prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace monitoring port-forward $POD_NAME 9090:9090 &
PROMETHEUS_PID=$!

POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/name=jaeger,app.kubernetes.io/instance=jaeger" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace monitoring port-forward $POD_NAME 16686:16686 &
JAEGER_PID=$!

POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace monitoring port-forward $POD_NAME 3000:3000 &
GRAFANA_PID=$!

GRAFANA_PASSWORD=$(kubectl get secret grafana-admin --namespace monitoring -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 -d)

sleep 2s

open http://localhost:8080 &
open http://localhost:9090 &
open http://localhost:16686 &
open http://localhost:3000 &

echo "======================================================"
echo "Grafana credentials"
echo "  - username: admin"
echo "  - password: "$GRAFANA_PASSWORD
echo ""
echo ""
echo "Press a key to end ports forwarding ..."
echo ""
echo "======================================================"
read -n 1

kill $KAFKA_UI_PID
kill $PROMETHEUS_PID
kill $JAEGER_PID
kill $GRAFANA_PID

