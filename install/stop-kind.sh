#!/bin/sh
set -o errexit

# delete the kind cluster
kind delete cluster

# kill the cloud-provider-kind process
# sudo pkill cloud-provider-kind

