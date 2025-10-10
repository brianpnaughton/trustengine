#!/bin/sh
set -o errexit

CURRENT_DIR=$(pwd)
# remove install/kind from the end of the CURRENT_DIR to get the ROOT directory
CURRENT_DIR=${CURRENT_DIR%/install}

echo "Current directory: ${CURRENT_DIR}"

reg_name='kind-registry'
reg_port='5001'

docker kill "${reg_name}" || true
docker rm "${reg_name}" || true
# docker system prune -f

sudo rm -rf ${CURRENT_DIR}/services/postgres/data
# remove cloud-provider-kind log
# CURRENT_DIR=$(pwd)
# rm ${CURRENT_DIR}/cloud-provider-kind.log
