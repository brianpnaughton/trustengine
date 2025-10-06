import kopf
import logging
from graph.lifecycle_tasks import update_network_node

logger = logging.getLogger(__name__)

#########################################################################
# Create a vyos router appliance
#########################################################################
@kopf.on.create('google.dev', 'v1', 'vyosrouter')
async def vyosrouter(body,spec, name, namespace, uid, logger, **kwargs):
    logger.debug(f"A vyos router handler is called with spec: {spec}")


  
