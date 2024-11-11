#!/bin/bash

helm uninstall --namespace infra kafka-ui
helm uninstall --namespace infra kafka
helm uninstall --namespace monitoring jaeger
helm uninstall --namespace monitoring loki
helm uninstall --namespace monitoring grafana
helm uninstall --namespace monitoring prometheus
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
helm uninstall --namespace monitoring metrics-server
kind delete cluster
