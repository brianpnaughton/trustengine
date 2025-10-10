import kopf
import logging

logger = logging.getLogger(__name__)

#########################################################################
# Create a docker network
#########################################################################
@kopf.on.create('guardian.dev', 'v1', 'vyosnetwork')
async def vyosnetwork(body,spec, name, namespace, uid, logger, **kwargs):
    logger.debug(f"A vyos network handler is called with spec: {spec}")


