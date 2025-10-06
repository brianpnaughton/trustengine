import kopf
import logging
from graph.lifecycle_tasks import update_network_node

logger = logging.getLogger(__name__)

#########################################################################
# Create a docker network
#########################################################################
@kopf.on.create('google.dev', 'v1', 'dockernetwork')
async def dockernetwork(body,spec, name, namespace, uid, logger, **kwargs):
    logger.debug(f"A docker network handler is called with spec: {spec}")


  