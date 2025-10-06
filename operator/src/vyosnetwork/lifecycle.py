import kopf
import logging

logger = logging.getLogger(__name__)

#########################################################################
# Create a docker network
#########################################################################
@kopf.on.create('guardian.dev', 'v1', 'dockernetwork')
async def dockernetwork(body,spec, name, namespace, uid, logger, **kwargs):
    logger.debug(f"A docker network handler is called with spec: {spec}")


