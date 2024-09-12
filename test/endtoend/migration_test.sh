#!/bin/bash

source ./test/endtoend/utils.sh

# Test setup
echo "Creating Kind cluster"
kind create cluster --wait 30s --name kind-migration
kind export kubeconfig --name kind-migration

# Check vitess cluster is running properly
echo "Apply operator.yaml"
kubectl apply -f "test/endtoend/k8s/operator.yaml"
check_pod_status_with_timeout "vitess-operator(.*)1/1(.*)Running(.*)"

echo "Apply cluster.yaml"
kubectl apply -f "test/endtoend/k8s/cluster.yaml"
check_pod_status_with_timeout "example-zone1-vtctld(.*)1/1(.*)Running(.*)"
check_pod_status_with_timeout "example-zone1-vtgate(.*)1/1(.*)Running(.*)"
check_pod_status_with_timeout "example-etcd(.*)1/1(.*)Running(.*)" 3
check_pod_status_with_timeout "mysql(.*)1/1(.*)Running(.*)" 2

echo "Apply setup-replication-job.yaml"
kubectl apply -f "test/endtoend/k8s/setup-replication-job.yaml"
check_pod_status_with_timeout "example-vttablet-zone1(.*)1/1(.*)Running(.*)" 2

./test/endtoend/pf.sh > /dev/null 2>&1 &
sleep 5

# Teardown
# echo "Deleting Kind cluster."
# kind delete cluster --name kind-migration
