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
# For Lambda containers: /var/task/.signing_key
# For ECS containers: /app/.signing_key
SIGNING_KEY_PATHS = [
    "/var/task/.signing_key",  # Lambda
    "/app/.signing_key",       # ECS/local
]


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
            # Try file paths (production - embedded in image)
            for path in SIGNING_KEY_PATHS:
                if os.path.exists(path):
                    with open(path, 'r') as f:
                        key = f.read().strip()
                        logger.info(f"Signing key loaded from: {path}")
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

    def _generate_signature(self, timestamp: str, nonce: str, body_hash: str = "") -> str:
        """Generate HMAC signature for the request."""
        # Include body hash if provided (for request body integrity)
        if body_hash:
            message = f"{timestamp}:{nonce}:{self.client_account}:{body_hash}"
        else:
            message = f"{timestamp}:{nonce}:{self.client_account}"

        signature = hmac.new(
            key=self.signing_key.encode('utf-8'),
            msg=message.encode('utf-8'),
            digestmod=hashlib.sha256
        ).hexdigest()
        return signature

    def _validate_integrity_hash(self, prompts: dict) -> bool:
        """
        Validate the integrity hash to ensure prompts weren't tampered with in transit.
        """
        received_hash = prompts.get('_integrity_hash', '')
        if not received_hash:
            logger.warning("No integrity hash in response - skipping validation")
            return True

        # Compute expected hash
        system = prompts.get('system_prompt', '')
        instruction = prompts.get('instruction_prompt', '')
        combined = f"{system}|{instruction}"
        expected_hash = hashlib.sha256(combined.encode()).hexdigest()[:16]

        if received_hash != expected_hash:
            logger.error(f"INTEGRITY CHECK FAILED! Expected {expected_hash}, got {received_hash}")
            return False

        logger.info("Prompt integrity hash validated successfully")
        return True

    def fetch_prompts(self) -> dict:
        """
        Fetch prompts from the gatekeeper.

        Generates a signed request that only our legitimate container can create.
        Also validates the integrity hash to detect tampering.
        """
        timestamp = str(int(time.time()))
        nonce = secrets.token_hex(16)

        # Request body (empty JSON for get-prompts, but hash it for integrity)
        body = "{}"
        body_hash = hashlib.sha256(body.encode('utf-8')).hexdigest()[:16]

        # Generate signature including body hash for request integrity
        signature = self._generate_signature(timestamp, nonce, body_hash)

        headers = {
            'X-Signature': signature,
            'X-Timestamp': timestamp,
            'X-Nonce': nonce,
            'X-Client-Account': self.client_account,
            'X-Body-Hash': body_hash,
            'Content-Type': 'application/json'
        }

        try:
            logger.info(f"Fetching prompts from gatekeeper: {self.gatekeeper_url}")

            with httpx.Client(timeout=30.0) as client:
                response = client.post(self.gatekeeper_url, headers=headers, content=body)

            if response.status_code == 200:
                prompts = response.json()

                # Validate integrity hash
                if not self._validate_integrity_hash(prompts):
                    raise RuntimeError("SECURITY: Prompt integrity validation failed - possible tampering!")

                # Remove internal hash from response
                prompts.pop('_integrity_hash', None)

                logger.info("Successfully fetched and validated prompts from gatekeeper")
                return prompts
            else:
                logger.error(f"Gatekeeper returned error: {response.status_code} - {response.text}")
                raise RuntimeError(f"Gatekeeper error: {response.status_code}")

        except httpx.RequestError as e:
            logger.error(f"Failed to connect to gatekeeper: {e}")
            raise RuntimeError(f"Cannot connect to gatekeeper: {e}")
