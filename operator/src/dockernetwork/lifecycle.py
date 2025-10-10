import kopf
import logging
from dockernetwork.lifecycle_tasks import install_docker_network

logger = logging.getLogger(__name__)

#########################################################################
# Create a docker network
#########################################################################
@kopf.on.create('guardian.dev', 'v1', 'dockernetwork')
async def dockernetwork(body,spec, name, namespace, uid, logger, **kwargs):
    logger.info(f"A docker network handler is called with spec: {spec}")

    await install_docker_network()

    return {"message": "Docker network created"}
