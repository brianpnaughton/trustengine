import kopf
import logging

logger = logging.getLogger(__name__)

#########################################################################
# Create a vyos router appliance
#########################################################################
@kopf.on.create('guardian.dev', 'v1', 'vyosrouter')
async def vyosrouter(body,spec, name, namespace, uid, logger, **kwargs):
    logger.debug(f"A vyos router handler is called with spec: {spec}")


  
