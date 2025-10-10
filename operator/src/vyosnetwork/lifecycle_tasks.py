import asyncio
import ansible_runner
import os
import utils.constants as constants
import logging
import kopf

logger = logging.getLogger(__name__)

#########################################################################
# Ansible playbook to create vyos network
#########################################################################
async def create_vyos_network():
    logger.info(f"Create VyOS Network")

    extravars = {
    }

    hosts = {
        'hosts': {
            'target': {
                'ansible_host': os.getenv("HOST_IP_ADDRESS"),
                'ansible_user': os.getenv("VM_USER"),
                'ansible_password': os.getenv("VM_PASSWORD"),
                'ansible_become_password': os.getenv("VM_PASSWORD"),
                'ansible_connection': 'ssh',
                'ansible_ssh_common_args': '-o StrictHostKeyChecking=no'
            }
        }
    }
    logger.info(hosts)
    logger.info(extravars)

    def run_ansible():
        """Wrapper function to run ansible_runner.run_async"""
        thread, runner = ansible_runner.run_async(
            private_data_dir=constants.basedir+"/vyosnetwork/playbooks", 
            inventory={'all': hosts},
            playbook='install.yaml',
            extravars=extravars
        )
        # Wait for the thread to complete
        thread.join()
        return runner

    # Execute in thread pool to avoid blocking the async event loop
    loop = asyncio.get_event_loop()
    r = await loop.run_in_executor(None, run_ansible)

    if r.status != 'successful':
        raise kopf.PermanentError("Error.", delay=10)
