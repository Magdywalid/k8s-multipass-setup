# Kubernetes Cluster on Multipass

This repository provides scripts to quickly set up a **3-node Kubernetes cluster** using **Multipass** on macOS.  

It includes:

- Master and worker node creation
- Kubernetes v1.34 installation with latest kubeadm
- Container runtime configuration (containerd)
- Flannel CNI network setup
- Host-side logging

---

## **Requirements**

- macOS with [Multipass](https://multipass.run/) installed
- [Git](https://git-scm.com/) installed
- Internet access for downloading Kubernetes packages and Flannel CNI

---

## **Setup Instructions**

### **Step 1: Clone the repository**

```bash
git clone https://github.com/Magdywalid/k8s-multipass-setup
cd k8s-ins-proj


### **Step 2: Create Multipass VMs**
chmod +x create-vms.sh
./create-vms.sh

    # This will create 1 master and 2 worker nodes.
    # Use (multipass list) to see the IPs assigned.


### **Step 3: Setup Kubernetes cluster**
chmod +x kube-setup.sh
./kube-setup.sh

    # The script dynamically detects the master node IP.
    # Installs kubeadm, kubectl, kubelet, and containerd.
    # Configures network settings (IPv4 forwarding, bridge-nf-call-iptables).
    # Applies Flannel CNI for pod networking.
    # Automatically joins worker nodes.
    # Logs are saved on the host machine in host-setup.log.

### **Step 4: Setup Kubernetes cluster**
multipass exec k8s-master -- kubectl get nodes
    # you should see all 3 nodes in Ready status.


### **optional: Delete all created VMs**
chmod +x delete-vms.sh
./delete-vms.sh
