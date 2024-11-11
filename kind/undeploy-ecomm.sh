#!/bin/bash

helm uninstall --namespace ecomm-kind ecomm-gateway-admin-bff
helm uninstall --namespace ecomm-kind ecomm-admin-bff
helm uninstall --namespace ecomm-kind ecomm-limiter-kafka-mps
helm uninstall --namespace ecomm-kind ecomm-limiter-processor
helm uninstall --namespace ecomm-kind ecomm-orders
helm uninstall --namespace ecomm-kind ecomm-products
helm uninstall --namespace ecomm-kind ecomm-users
helm uninstall --namespace ecomm-kind ecomm-monitoring

