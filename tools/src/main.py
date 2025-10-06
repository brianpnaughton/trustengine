import logging
import os
import asyncio
import uvicorn
from utils.globals import networkagent_mcp


log_format = "%(asctime)s::%(levelname)s::%(name)s::"\
             "%(filename)s::%(lineno)d::%(message)s"
logging.basicConfig(level=logging.INFO, format=log_format)
logger = logging.getLogger(__name__)
BASE_DIR = os.path.dirname(os.path.realpath(__file__))

# import all tools
import tools.spanner

sse_app = networkagent_mcp.http_app(transport="sse")

async def main():
    """Starts the server."""
    logger.info("starting network agent tools server...")
    config = uvicorn.Config(app=sse_app, host="0.0.0.0", port=8080, log_level="info", workers=1)
    server = uvicorn.Server(config)
    await server.serve()

if __name__ == "__main__":
    asyncio.run(main())
