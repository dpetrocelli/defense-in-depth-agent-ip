"""
Prompt Gatekeeper Lambda
========================
Validates requests using embedded signing key before returning prompts.
This ensures only our legitimate container image can retrieve the prompts.
"""

import os
import json
import hmac
import hashlib
import time
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
SIGNING_KEY = os.environ.get('SIGNING_KEY', '')
PROMPT_SECRET_ARN = os.environ.get('PROMPT_SECRET_ARN', '')
ALLOWED_CLIENT_ACCOUNTS = os.environ.get('ALLOWED_CLIENT_ACCOUNTS', '').split(',')
REQUEST_TIMEOUT_SECONDS = 300  # 5 minutes - requests older than this are rejected

secrets_client = boto3.client('secretsmanager')


def lambda_handler(event, context):
    """
    Validate the request signature and return prompts if valid.

    Expected headers:
    - X-Signature: HMAC signature of the request
    - X-Timestamp: Unix timestamp of the request
    - X-Nonce: Random nonce for replay protection
    - X-Client-Account: AWS account ID of the caller
    """
    try:
        # Extract headers (API Gateway lowercases them)
        headers = {k.lower(): v for k, v in (event.get('headers') or {}).items()}

        signature = headers.get('x-signature', '')
        timestamp = headers.get('x-timestamp', '')
        nonce = headers.get('x-nonce', '')
        client_account = headers.get('x-client-account', '')

        # Log request (without sensitive data)
        logger.info(f"Gatekeeper request from account: {client_account}")

        # Validate required headers
        if not all([signature, timestamp, nonce, client_account]):
            logger.warning(f"Missing required headers. Account: {client_account}")
            return error_response(400, "Missing required headers")

        # Validate client account
        if client_account not in ALLOWED_CLIENT_ACCOUNTS:
            logger.warning(f"Unauthorized client account: {client_account}")
            return error_response(403, "Unauthorized client account")

        # Validate timestamp (prevent replay attacks)
        try:
            request_time = int(timestamp)
            current_time = int(time.time())
            if abs(current_time - request_time) > REQUEST_TIMEOUT_SECONDS:
                logger.warning(f"Request timestamp too old. Account: {client_account}")
                return error_response(403, "Request expired")
        except ValueError:
            return error_response(400, "Invalid timestamp format")

        # Validate signature
        expected_signature = generate_signature(timestamp, nonce, client_account)
        if not hmac.compare_digest(signature, expected_signature):
            logger.warning(f"Invalid signature from account: {client_account}")
            # Alert on invalid signature attempts
            return error_response(403, "Invalid signature")

        # Signature valid - fetch and return the prompts
        logger.info(f"Valid request from account: {client_account}")
        prompts = get_prompts()

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps(prompts)
        }

    except Exception as e:
        logger.error(f"Gatekeeper error: {str(e)}")
        return error_response(500, "Internal server error")


def generate_signature(timestamp: str, nonce: str, client_account: str) -> str:
    """Generate the expected HMAC signature."""
    message = f"{timestamp}:{nonce}:{client_account}"
    signature = hmac.new(
        key=SIGNING_KEY.encode('utf-8'),
        msg=message.encode('utf-8'),
        digestmod=hashlib.sha256
    ).hexdigest()
    return signature


def get_prompts() -> dict:
    """Fetch prompts from Secrets Manager."""
    try:
        response = secrets_client.get_secret_value(SecretId=PROMPT_SECRET_ARN)
        return json.loads(response['SecretString'])
    except ClientError as e:
        logger.error(f"Failed to fetch prompts: {e}")
        raise


def error_response(status_code: int, message: str) -> dict:
    """Generate an error response."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps({'error': message})
    }
