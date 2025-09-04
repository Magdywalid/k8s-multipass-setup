#!/bin/bash
# Create 1 master + 2 worker nodes
echo "Creating Multipass VMs..."

multipass launch --name k8s-master --memory 2G --disk 10G --cpus 2 
multipass launch --name k8s-worker1 --memory 2G --disk 10G --cpus 2 
multipass launch --name k8s-worker2 --memory 2G --disk 10G --cpus 2 

echo "All VMs created!"
multipass list | tee -a vms-details.txt
