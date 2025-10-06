import kopf
import logging
from graph.lifecycle_tasks import update_network_node

logger = logging.getLogger(__name__)

#########################################################################
# Create a vyos network
#########################################################################
@kopf.on.create('google.dev', 'v1', 'vyosnetwork')
async def vyosnetwork(body,spec, name, namespace, uid, logger, **kwargs):
    logger.debug(f"A vyos network handler is called with spec: {spec}")


  