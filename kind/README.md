# Kind deployment

This folder contains instructions to deploy ecomm services to [Kind](https://kind.sigs.k8s.io/) kubernetes.

## Requirements

* [Docker](https://www.docker.com/)
* [Go lang 1.16+](https://go.dev/dl/)
* [kubectl](https://kubernetes.io/es/docs/reference/kubectl/)
* [Helm](https://helm.sh/)
* [Kind 0.24.0](https://github.com/kubernetes-sigs/kind/)

## Installation

1. Install Go lang from https://go.dev/dl/ and add go bin folder in your PATH environment variable
```shell
export PATH=<GO_HOME_DIR>/bin:$PATH
```

2. Install Kind from https://github.com/kubernetes-sigs/kind/
```shell
go install sigs.k8s.io/kind@v0.24.0
```

3. Add go bin to PATH
```shell
export PATH=<GO_BIN_DIR>:$PATH
```
Go download and install packages and bin in a folder which is defined in `go env GOPATH`. In linux by default is $HOME/go. So path will be: `export PATH=$HOME/go/bin:$PATH`

4. Create cluster
```shell
kind create cluster
```


kind create cluster --config=./kind-config.yaml


https://semaphoreci.com/blog/prometheus-grafana-kubernetes-helm

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana

// helm install prometheus oci://registry-1.docker.io/bitnamicharts/prometheus

helm install kafka oci://registry-1.docker.io/bitnamicharts/kafka

helm install ecomm-monitoring ./../k8s/10-monitoring --namespace ecomm-kind --create-namespace -f ./../k8s/10-monitoring/kind.yaml
helm install ecomm-users ./../k8s/20-users --namespace ecomm-kind --create-namespace -f ./../k8s/20-users/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-products ./../k8s/30-products --namespace ecomm-kind --create-namespace -f ./../k8s/30-products/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-orders ./../k8s/40-orders --namespace ecomm-kind --create-namespace -f ./../k8s/40-orders/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-admin-bff ./../k8s/50-admin-bff --namespace ecomm-kind --create-namespace -f ./../k8s/50-admin-bff/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
helm install ecomm-limiter-processor ./../k8s/60-limiter-processor --namespace ecomm-kind --create-namespace -f ./../k8s/60-limiter-processor/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-limiter-kafka-mps ./../k8s/70-limiter-kafka-mps --namespace ecomm-kind --create-namespace -f ./../k8s/70-limiter-kafka-mps/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
helm install ecomm-gateway-admin-bff ./../k8s/80-gateway-admin-bff --namespace ecomm-kind --create-namespace -f ./../k8s/80-gateway-admin-bff/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace default -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)

helm uninstall --namespace ecomm-kind ecomm-gateway-admin-bff
helm uninstall --namespace ecomm-kind ecomm-limiter-kafka-mps
helm uninstall --namespace ecomm-kind ecomm-limiter-processor
helm uninstall --namespace ecomm-kind ecomm-admin-bff
helm uninstall --namespace ecomm-kind ecomm-orders
helm uninstall --namespace ecomm-kind ecomm-products
helm uninstall --namespace ecomm-kind ecomm-users
helm uninstall --namespace ecomm-kind ecomm-monitoring

helm uninstall kafka

helm uninstall prometheus

kind delete cluster

