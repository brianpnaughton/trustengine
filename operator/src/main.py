import os
import sys
import utils.constants as constants

import logging
logger = logging.getLogger(__name__)

import kopf
import asyncio

# get base directory to figure out where playbooks are located
if os.getenv("BASEDIR")==None:
    constants.basedir=os.getcwd()
else:
    constants.basedir=os.getenv("BASEDIR")
logger.info("Base directory is %s", constants.basedir)

def import_modules():
    logger.info("importing all modules immediately")
  
    import dockernetwork.lifecycle
    import vyosnetwork.lifecycle
    import vyos.lifecycle

@kopf.on.startup()
async def configure(settings: kopf.OperatorSettings, **_):    
    import_modules()
    
# Login with k8s client
@kopf.on.login()
def login_fn(**kwargs):
    return kopf.login_via_client(**kwargs)

@kopf.on.probe()
def get_readiness(memo: kopf.Memo, **kwargs):
    # Add checks for dependencies like Spanner, etc.
    # For now, we'll just return the time
    from datetime import datetime
    return {"ready": True, "time": str(datetime.utcnow())}
