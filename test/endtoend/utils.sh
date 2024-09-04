# Function to check the status of pods with a timeout
# Arguments:
#   $1 - regex to match pod names
#   $2 - number of pods to match (defaults to 1)
function check_pod_status_with_timeout() {
  local regex=$1
  local nb=${2:-1}  # Default to 1 if not provided

  # Loop to check pod status
  while [[ $counter -le 240 ]]; do
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
  exit 1
}