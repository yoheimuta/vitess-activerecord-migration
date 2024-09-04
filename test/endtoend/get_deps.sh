#!/bin/bash

# Function to install kind
install_kind() {
  echo "Installing kind..."
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
  chmod +x ./kind
  mv ./kind /usr/local/bin/kind
}

# Function to install kubectl
install_kubectl() {
  echo "Installing kubectl..."
  curl -Lo ./kubectl https://dl.k8s.io/release/"$(curl -L -s https://dl.k8s.io/release/stable.txt)"/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  mv ./kubectl /usr/local/bin/kubectl
}

# Check if kind is installed
if ! command -v kind &> /dev/null; then
  install_kind
else
  echo "kind is already installed"
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  install_kubectl
else
  echo "kubectl is already installed"
fi