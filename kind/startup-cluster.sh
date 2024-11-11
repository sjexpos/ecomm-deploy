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

