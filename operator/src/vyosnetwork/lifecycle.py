import kopf
import logging
from vyosnetwork.lifecycle_tasks import create_vyos_network

logger = logging.getLogger(__name__)

#########################################################################
# Create a docker network
#########################################################################
@kopf.on.create('guardian.dev', 'v1', 'vyosnetwork')
async def vyosnetwork(body,spec, name, namespace, uid, logger, **kwargs):
    logger.info(f"A vyos network handler is called with spec: {spec}")

    await create_vyos_network()

    return {'message': f"Vyos network {name} created"}