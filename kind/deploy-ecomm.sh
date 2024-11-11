#!/bin/bash

# Installing monitoring service
helm install ecomm-monitoring ./../k8s/10-monitoring --namespace ecomm-kind --create-namespace -f ./../k8s/10-monitoring/kind.yaml
echo "Waiting for monitoring service ..."
sleep 2s
kubectl wait --namespace ecomm-kind --for=condition=ready pod --selector=app=monitoring-service --timeout=300s

# Installing users service
helm install ecomm-users ./../k8s/20-users --namespace ecomm-kind --create-namespace -f ./../k8s/20-users/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
echo "Waiting for users service ..."
sleep 2s
kubectl wait --namespace ecomm-kind --for=condition=ready pod --selector=app=users-service --timeout=300s

# Installing products service
helm install ecomm-products ./../k8s/30-products --namespace ecomm-kind --create-namespace -f ./../k8s/30-products/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
echo "Waiting for products service ..."
sleep 2s
kubectl wait --namespace ecomm-kind --for=condition=ready pod --selector=app=products-service --timeout=300s

# Installing orders service
helm install ecomm-orders ./../k8s/40-orders --namespace ecomm-kind --create-namespace -f ./../k8s/40-orders/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
echo "Waiting for orders service ..."
sleep 2s
kubectl wait --namespace ecomm-kind --for=condition=ready pod --selector=app=orders-service --timeout=300s

# Installing limiter-processor service
helm install ecomm-limiter-processor ./../k8s/60-limiter-processor --namespace ecomm-kind --create-namespace -f ./../k8s/60-limiter-processor/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
echo "Waiting for limiter-processor service ..."
sleep 2s
kubectl wait --namespace ecomm-kind --for=condition=ready pod --selector=app=limiter-processor-service --timeout=300s

# Installing limiter-kafka-mps service
helm install ecomm-limiter-kafka-mps ./../k8s/70-limiter-kafka-mps --namespace ecomm-kind --create-namespace -f ./../k8s/70-limiter-kafka-mps/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
echo "Waiting for limiter-kafka-mps service ..."
sleep 2s
kubectl wait --namespace ecomm-kind --for=condition=ready pod --selector=app=limiter-kafka-mps --timeout=300s

# Installing admin-bff service
helm install ecomm-admin-bff ./../k8s/50-admin-bff --namespace ecomm-kind --create-namespace -f ./../k8s/50-admin-bff/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane)
echo "Waiting for admin-bff service ..."
sleep 2s
kubectl wait --namespace ecomm-kind --for=condition=ready pod --selector=app=admin-bff --timeout=300s

# Installing gateway-admin-bff service
helm install ecomm-gateway-admin-bff ./../k8s/80-gateway-admin-bff --namespace ecomm-kind --create-namespace -f ./../k8s/80-gateway-admin-bff/kind.yaml --set kind_gateway_id=$(docker inspect --format='{{.NetworkSettings.Networks.kind.Gateway}}' kind-control-plane) --set kafka_user=user1 --set kafka_password=$(kubectl get secret kafka-user-passwords --namespace infra -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
echo "Waiting for gateway-admin-bff service ..."
sleep 2s
kubectl wait --namespace ecomm-kind --for=condition=ready pod --selector=app=gateway-admin-bff --timeout=300s

open http://gateway-admin-bff.kind.ecomm.io/swagger-ui.html &

