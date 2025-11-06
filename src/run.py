import os
import logging
from bw_client import BitwardenClient
from vault_sync import SyncPlanner

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

def require_env(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return val

def main():
    # ✅ Required for both vaults
    src_client_id = require_env("SRC_BW_CLIENT_ID")
    src_client_secret = require_env("SRC_BW_CLIENT_SECRET")
    src_pass = require_env("SRC_BW_PASSWORD")
    src_server = os.getenv("SRC_BW_SERVER")  # optional

    dst_client_id = require_env("DST_BW_CLIENT_ID")
    dst_client_secret = require_env("DST_BW_CLIENT_SECRET")
    dst_pass = require_env("DST_BW_PASSWORD")
    dst_server = os.getenv("DST_BW_SERVER")  # optional

    # Create clients
    logger.info("🔐 Connecting to source vault...")
    source = BitwardenClient(bw_cmd='bw-src', server=src_server, client_id=src_client_id, client_secret=src_client_secret, use_api_key=True)
    source.login()
    source.unlock(src_pass)

    logger.info("🔐 Connecting to destination vault...")
    destination = BitwardenClient(bw_cmd='bw-dest', server=dst_server, client_id=dst_client_id, client_secret=dst_client_secret, use_api_key=True)
    destination.login()
    destination.unlock(dst_pass)

    # Run dry-run plan
    planner = SyncPlanner(source, destination)
    to_create, to_update, to_delete = planner.plan()

    logger.info("\n✅ DRY RUN RESULT")
    logger.info("-------------------------------")
    logger.info(f"Create: {len(to_create)}")
    logger.info(f"Update: {len(to_update)}")
    logger.info(f"Delete: {len(to_delete)}")
    logger.info("-------------------------------")

    for item in to_create:
        logger.info(f"[CREATE] {item.get('name')}")

    for item in to_update:
        logger.info(f"[UPDATE] {item[0].get('name')}")

    for item in to_delete:
        logger.info(f"[DELETE] {item.get('name')}")

    logger.info("\n✅ Sync planning completed — no changes applied!")

if __name__ == "__main__":
    main()