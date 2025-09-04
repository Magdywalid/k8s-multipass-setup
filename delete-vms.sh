#!/bin/bash

# List current VMs
multipass list

# Stop all VMs
multipass stop k8s-master k8s-worker1 k8s-worker2

# Delete them
multipass delete k8s-master k8s-worker1 k8s-worker2

# Purge to remove all data completely
multipass purge