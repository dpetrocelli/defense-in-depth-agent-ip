"""
Gatekeeper Client
=================
Secure client for fetching prompts from the Lambda Gatekeeper.
Uses the embedded signing key to authenticate requests.
"""

import os
import hmac
import hashlib
import time
import secrets
import logging
import httpx
import boto3

logger = logging.getLogger(__name__)

# Path to the signing key file (embedded in container image at build time)
SIGNING_KEY_PATH = "/app/.signing_key"


class GatekeeperClient:
    """
    Client for securely fetching prompts from the Lambda Gatekeeper.

    The signing key is embedded in the container image at build time.
    Only our legitimate image can generate valid signatures.
    """

    def __init__(self, gatekeeper_url: str):
        self.gatekeeper_url = gatekeeper_url
        self.signing_key = self._load_signing_key()
        self.client_account = self._get_account_id()

    def _load_signing_key(self) -> str:
        """Load the signing key from the embedded file."""
        try:
            # First try file (production - embedded in image)
            if os.path.exists(SIGNING_KEY_PATH):
                with open(SIGNING_KEY_PATH, 'r') as f:
                    key = f.read().strip()
                    logger.info("Signing key loaded from embedded file")
                    return key

            # Fallback to environment variable (for local development only)
            env_key = os.environ.get('GATEKEEPER_SIGNING_KEY', '')
            if env_key:
                logger.warning("Using signing key from environment variable (dev mode)")
                return env_key

            raise RuntimeError("No signing key found")

        except Exception as e:
            logger.error(f"Failed to load signing key: {e}")
            raise RuntimeError("Cannot initialize gatekeeper client: signing key unavailable")

    def _get_account_id(self) -> str:
        """Get the current AWS account ID."""
        try:
            sts = boto3.client('sts')
            return sts.get_caller_identity()['Account']
        except Exception as e:
            logger.error(f"Failed to get account ID: {e}")
            raise

    def _generate_signature(self, timestamp: str, nonce: str) -> str:
        """Generate HMAC signature for the request."""
        message = f"{timestamp}:{nonce}:{self.client_account}"
        signature = hmac.new(
            key=self.signing_key.encode('utf-8'),
            msg=message.encode('utf-8'),
            digestmod=hashlib.sha256
        ).hexdigest()
        return signature

    def fetch_prompts(self) -> dict:
        """
        Fetch prompts from the gatekeeper.

        Generates a signed request that only our legitimate container can create.
        """
        timestamp = str(int(time.time()))
        nonce = secrets.token_hex(16)
        signature = self._generate_signature(timestamp, nonce)

        headers = {
            'X-Signature': signature,
            'X-Timestamp': timestamp,
            'X-Nonce': nonce,
            'X-Client-Account': self.client_account,
            'Content-Type': 'application/json'
        }

        try:
            logger.info(f"Fetching prompts from gatekeeper: {self.gatekeeper_url}")

            with httpx.Client(timeout=30.0) as client:
                response = client.post(self.gatekeeper_url, headers=headers)

            if response.status_code == 200:
                logger.info("Successfully fetched prompts from gatekeeper")
                return response.json()
            else:
                logger.error(f"Gatekeeper returned error: {response.status_code} - {response.text}")
                raise RuntimeError(f"Gatekeeper error: {response.status_code}")

        except httpx.RequestError as e:
            logger.error(f"Failed to connect to gatekeeper: {e}")
            raise RuntimeError(f"Cannot connect to gatekeeper: {e}")
