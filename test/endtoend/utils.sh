# Function to check the status of pods with a timeout
# Arguments:
#   $1 - regex to match pod names
#   $2 - number of pods to match (defaults to 1)
function check_pod_status_with_timeout() {
  local regex=$1
  local nb=${2:-1}  # Default to 1 if not provided

  # Loop to check pod status
  while [[ $counter -le 300 ]]; do
    local out
    out=$(kubectl get pods)
    if [[ $(echo "$out" | grep -c -E "$regex") -eq "$nb" ]]; then
      echo "$regex found"
      return 0
    fi
    sleep 1
    ((counter++))
  done

  # Timeout error handling
  echo -e "ERROR: Timeout while waiting for pod matching:\n$out\nRegex: $regex"
  outputFailedPodLogs
  exit 1
}

# Function to check if a keyspace is serving
# Arguments:
#   $1 - keyspace name
#   $2 - shard name
#   $3 - number of replicas
function checkKeyspaceServing() {
  ks=$1
  shard=$2
  nb_of_replica=$3

  # Use mariadb for now because of "mysql: Deprecated program name. It will be removed in a future release, use '/usr/bin/mariadb' instead."
  # And skip ssl to address "ERROR 2026 (HY000): TLS/SSL error: SSL is required, but the server does not support it"
  out=$(mariadb --skip-ssl -h 127.0.0.1 -u user --table --execute="show vitess_tablets")
  numtablets=$(echo "$out" | grep -E "$ks(.*)$shard(.*)PRIMARY(.*)SERVING|$ks(.*)$shard(.*)REPLICA(.*)SERVING|$ks(.*)$shard(.*)RDONLY(.*)SERVING" | wc -l)
  if [[ $numtablets -ge $((nb_of_replica+1)) ]]; then
    echo "Shard $ks/$shard is serving"
    return 0
  else
    echo "Shard $ks/$shard is not fully serving. Output: $out"
    return 1
  fi
}

# Function to output logs for unhealthy pods
function outputFailedPodLogs() {
  # Get all pods with Running state but not fully ready (e.g., 0/1 containers ready)
  unhealthy_pods=$(kubectl get pods | awk '$2 ~ /0\/1/&& ($3 == "Running" || $3 == "Completed")')

  if [ -z "$unhealthy_pods" ]; then
    echo "No unhealthy pods found."
  else
    echo "Unhealthy pods:"
    echo "$unhealthy_pods"

    # Stream logs for each unhealthy pod
    while IFS= read -r pod; do
      pod_name=$(echo "$pod" | awk '{print $1}')
      echo "Fetching logs for pod: $pod_name"

      # Check if the pod has multiple containers
      containers=$(kubectl get pod "$pod_name" -o jsonpath='{.spec.containers[*].name}')
      for container in $containers; do
        echo "Fetching logs for container: $container in pod: $pod_name"
        kubectl logs "$pod_name" -c "$container"
      done
    done <<< "$unhealthy_pods"
  fi
  }
