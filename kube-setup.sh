#!/bin/bash

set -e  # Exit immediately on any error

# Kubernetes setup on Multipass nodes (created)

MASTER_IP=$(multipass info k8s-master | awk '/IPv4/ {print $2}')  
NODES=("k8s-master" "k8s-worker1" "k8s-worker2")
LOG_FILE="host-setup.log"

# Clear previous log file
> $LOG_FILE

# ------------------------
# Enable IPv4 forwarding
# ------------------------

enable_network_settings() {
  NODE=$1
  echo "Enabling IPv4 forwarding on $NODE..."
  multipass exec $NODE -- bash -c "
    sudo modprobe br_netfilter
    sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
  " | tee -a $LOG_FILE
}

# ------------------------
# Install Kubernetes & containerd
# ------------------------

install_k8s() {
  NODE=$1
  echo "Setting up Kubernetes on $NODE..."
  multipass exec $NODE -- bash -c "
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y containerd kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo swapoff -a
    sudo sed -i '/ swap / s/^/#/' /etc/fstab
    sudo sysctl --system
  " | tee -a $LOG_FILE
}

# ------------------------
# Step 1: Enable IPv4 forwarding on all nodes
# ------------------------

for NODE in "${NODES[@]}"; do
  enable_network_settings $NODE
done

# ------------------------
# Step 2: Install Kubernetes on all nodes
# ------------------------

for NODE in "${NODES[@]}"; do
  install_k8s $NODE
done

# ------------------------
# Step 3: Initialize master node
# ------------------------

echo "[k8s-master] Initializing master node..." | tee -a $LOG_FILE
multipass exec k8s-master -- bash -c "
  sudo kubeadm init --apiserver-advertise-address=$MASTER_IP --pod-network-cidr=10.244.0.0/16
" | tee -a $LOG_FILE

# ------------------------
# Step 4: Configure kubectl for master
# ------------------------
echo "[k8s-master] Setting up kubectl config..." | tee -a $LOG_FILE
multipass exec k8s-master -- bash -c "
  mkdir -p \$HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
" | tee -a $LOG_FILE

# ------------------------
# Step 5: Apply Flannel network
# ------------------------

echo "[k8s-master] Downloading and applying Flannel network..." | tee -a $LOG_FILE
multipass exec k8s-master -- bash -c "
  curl -O https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
  # Wait for master node to be Ready
  kubectl wait --for=condition=Ready node k8s-master --timeout=5m
  kubectl apply -f kube-flannel.yml
" | tee -a $LOG_FILE

# ------------------------
# Step 6: Join worker nodes
# ------------------------
echo "[k8s-master] Generating join command..." | tee -a $LOG_FILE
JOIN_CMD=$(multipass exec k8s-master -- kubeadm token create --print-join-command)

for NODE in "${NODES[@]}"; do
  if [ "$NODE" != "k8s-master" ]; then
    echo "[$NODE] Joining cluster..." | tee -a $LOG_FILE
    multipass exec $NODE -- bash -c "sudo $JOIN_CMD" | tee -a $LOG_FILE
  fi
done

# ------------------------
# Step 7: Verify cluster
# ------------------------

echo "[k8s-master] Kubernetes cluster setup completed! Nodes:" | tee -a $LOG_FILE
multipass exec k8s-master -- kubectl get nodes | tee -a $LOG_FILE