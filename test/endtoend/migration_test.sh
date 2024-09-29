#!/bin/bash

source ./test/endtoend/utils.sh

# Retry function for 'kind delete cluster'
retry_kind_delete_cluster() {
  local retries=10       # Number of retries
  local wait_time=5     # Time to wait between retries (in seconds)
  local attempt=1       # Current attempt counter

  while [ $attempt -le $retries ]; do
    echo "Attempt $attempt: Checking for existing Kind clusters..."
    if kind delete cluster --name kind-migration; then
      echo "Kind cluster deleted."
      return 0
    else
      echo "Error occurred. Retrying in $wait_time seconds..."
      ((attempt++))
      sleep $wait_time
    fi
  done

  echo "Failed to get clusters after $retries attempts."
  return 1
}

# Test setup
echo "Creating Kind cluster"
echo "DOCKER_HOST=${DOCKER_HOST}"
kind get clusters
retry_kind_delete_cluster || exit 1  # Exit if the retry function fails
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

echo "Start port-forwarding"
./test/endtoend/pf.sh > /dev/null 2>&1 &
sleep 5

echo "Complete setup"

# Teardown
# echo "Deleting Kind cluster."
# kind delete cluster --name kind-migration
