"""
Prompt Gatekeeper Lambda
========================
Validates requests using embedded signing key before returning prompts.
This ensures only our legitimate container image can retrieve the prompts.

Security features:
- HMAC-SHA256 signature validation
- Timestamp validation (5 min window)
- Nonce tracking (prevents replay attacks)
- Rate limiting per account
- Audit logging of all access attempts
- Alert on suspicious activity
"""

import os
import json
import hmac
import hashlib
import time
import logging
import boto3
from botocore.exceptions import ClientError
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
SIGNING_KEY = os.environ.get('SIGNING_KEY', '')
PROMPT_SECRET_ARN = os.environ.get('PROMPT_SECRET_ARN', '')
ALLOWED_CLIENT_ACCOUNTS = os.environ.get('ALLOWED_CLIENT_ACCOUNTS', '').split(',')
ALERT_SNS_TOPIC = os.environ.get('ALERT_SNS_TOPIC', '')
REQUEST_TIMEOUT_SECONDS = 300  # 5 minutes - requests older than this are rejected

# Rate limiting: max requests per account per minute
MAX_REQUESTS_PER_MINUTE = int(os.environ.get('MAX_REQUESTS_PER_MINUTE', '60'))

# IP allowlisting (optional): comma-separated list of allowed CIDRs
ALLOWED_IP_CIDRS = os.environ.get('ALLOWED_IP_CIDRS', '').split(',') if os.environ.get('ALLOWED_IP_CIDRS') else []

# In-memory tracking (resets on cold start, but good enough for basic protection)
_nonce_cache = {}  # {nonce: timestamp} - prevent replay
_rate_limit_cache = {}  # {account: [(timestamp, ...)]} - rate limiting
_failed_attempts = {}  # {account: count} - track failures

secrets_client = boto3.client('secretsmanager')
sns_client = boto3.client('sns') if ALERT_SNS_TOPIC else None


# =============================================================================
# Security: IP Allowlisting
# =============================================================================

def check_ip_allowed(source_ip: str) -> bool:
    """
    Check if source IP is in the allowed CIDR ranges.
    Returns True if allowed (or if no IP restrictions configured).
    """
    if not ALLOWED_IP_CIDRS or ALLOWED_IP_CIDRS == ['']:
        return True  # No IP restrictions

    try:
        import ipaddress
        ip = ipaddress.ip_address(source_ip)

        for cidr in ALLOWED_IP_CIDRS:
            if not cidr:
                continue
            try:
                network = ipaddress.ip_network(cidr.strip(), strict=False)
                if ip in network:
                    return True
            except ValueError:
                logger.warning(f"Invalid CIDR in allowlist: {cidr}")
                continue

        return False
    except Exception as e:
        logger.error(f"IP check error: {e}")
        return False  # Fail closed


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
        source_ip = event.get('requestContext', {}).get('http', {}).get('sourceIp', 'unknown')

        signature = headers.get('x-signature', '')
        timestamp = headers.get('x-timestamp', '')
        nonce = headers.get('x-nonce', '')
        client_account = headers.get('x-client-account', '')
        body_hash = headers.get('x-body-hash', '')  # Optional: hash of request body

        # =================================================================
        # AUDIT: Log every request
        # =================================================================
        audit_log("REQUEST", client_account, source_ip, {
            "has_signature": bool(signature),
            "has_timestamp": bool(timestamp),
            "has_nonce": bool(nonce)
        })

        # =================================================================
        # IP ALLOWLISTING: Check if source IP is allowed
        # =================================================================
        if not check_ip_allowed(source_ip):
            record_failed_attempt(client_account or "unknown", "ip_not_allowed", source_ip)
            audit_log("IP_BLOCKED", client_account or "unknown", source_ip)
            return error_response(403, "Access denied from this IP")

        # Validate required headers
        if not all([signature, timestamp, nonce, client_account]):
            record_failed_attempt(client_account, "missing_headers", source_ip)
            return error_response(400, "Missing required headers")

        # Validate client account
        if client_account not in ALLOWED_CLIENT_ACCOUNTS:
            record_failed_attempt(client_account, "unauthorized_account", source_ip)
            return error_response(403, "Unauthorized client account")

        # =================================================================
        # RATE LIMITING: Check request rate
        # =================================================================
        if not check_rate_limit(client_account):
            record_failed_attempt(client_account, "rate_limited", source_ip)
            audit_log("RATE_LIMITED", client_account, source_ip)
            return error_response(429, "Rate limit exceeded")

        # Validate timestamp (prevent replay attacks)
        try:
            request_time = int(timestamp)
            current_time = int(time.time())
            if abs(current_time - request_time) > REQUEST_TIMEOUT_SECONDS:
                record_failed_attempt(client_account, "expired_timestamp", source_ip)
                return error_response(403, "Request expired")
        except ValueError:
            record_failed_attempt(client_account, "invalid_timestamp", source_ip)
            return error_response(400, "Invalid timestamp format")

        # =================================================================
        # NONCE VALIDATION: Prevent replay with same nonce
        # =================================================================
        if not validate_nonce(nonce, request_time):
            record_failed_attempt(client_account, "replay_attack", source_ip)
            audit_log("REPLAY_ATTEMPT", client_account, source_ip, {"nonce": nonce[:8]})
            return error_response(403, "Nonce already used (replay attack detected)")

        # Validate signature (include body hash if provided for extra integrity)
        expected_signature = generate_signature(timestamp, nonce, client_account, body_hash)
        if not hmac.compare_digest(signature, expected_signature):
            record_failed_attempt(client_account, "invalid_signature", source_ip)
            return error_response(403, "Invalid signature")

        # If body hash provided, validate the actual body
        if body_hash:
            body = event.get('body', '') or ''
            actual_body_hash = hashlib.sha256(body.encode('utf-8')).hexdigest()[:16]
            if body_hash != actual_body_hash:
                record_failed_attempt(client_account, "body_tampered", source_ip)
                audit_log("BODY_TAMPERED", client_account, source_ip)
                return error_response(403, "Request body integrity check failed")

        # =================================================================
        # SUCCESS: Valid request
        # =================================================================
        audit_log("SUCCESS", client_account, source_ip)
        reset_failed_attempts(client_account)

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


def generate_signature(timestamp: str, nonce: str, client_account: str, body_hash: str = "") -> str:
    """Generate the expected HMAC signature."""
    # Include body hash if provided (for request body integrity)
    if body_hash:
        message = f"{timestamp}:{nonce}:{client_account}:{body_hash}"
    else:
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
        prompts = json.loads(response['SecretString'])

        # Add integrity hash for client-side validation
        system = prompts.get('system_prompt', '')
        instruction = prompts.get('instruction_prompt', '')
        combined = f"{system}|{instruction}"
        prompts['_integrity_hash'] = hashlib.sha256(combined.encode()).hexdigest()[:16]

        return prompts
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


# =============================================================================
# Security: Rate Limiting
# =============================================================================

def check_rate_limit(account: str) -> bool:
    """Check if account is within rate limit. Returns True if allowed."""
    current_time = time.time()
    one_minute_ago = current_time - 60

    # Clean old entries
    if account in _rate_limit_cache:
        _rate_limit_cache[account] = [
            ts for ts in _rate_limit_cache[account]
            if ts > one_minute_ago
        ]
    else:
        _rate_limit_cache[account] = []

    # Check limit
    if len(_rate_limit_cache[account]) >= MAX_REQUESTS_PER_MINUTE:
        return False

    # Record this request
    _rate_limit_cache[account].append(current_time)
    return True


# =============================================================================
# Security: Nonce Validation (prevent replay)
# =============================================================================

def validate_nonce(nonce: str, timestamp: int) -> bool:
    """
    Validate that nonce hasn't been used before.
    Returns True if nonce is valid (new).
    """
    current_time = time.time()

    # Clean old nonces (older than timeout window)
    expired_before = current_time - REQUEST_TIMEOUT_SECONDS - 60
    expired_nonces = [n for n, ts in _nonce_cache.items() if ts < expired_before]
    for n in expired_nonces:
        del _nonce_cache[n]

    # Check if nonce was already used
    if nonce in _nonce_cache:
        return False

    # Record nonce
    _nonce_cache[nonce] = timestamp
    return True


# =============================================================================
# Security: Failed Attempts Tracking
# =============================================================================

def record_failed_attempt(account: str, reason: str, source_ip: str):
    """Record a failed attempt and alert if threshold exceeded."""
    if account not in _failed_attempts:
        _failed_attempts[account] = 0

    _failed_attempts[account] += 1

    logger.warning(f"Failed attempt #{_failed_attempts[account]} from {account}: {reason}")

    # Alert if too many failures
    if _failed_attempts[account] >= 5:
        send_alert(
            "MULTIPLE_FAILED_ATTEMPTS",
            f"Account {account} has {_failed_attempts[account]} failed attempts. "
            f"Latest reason: {reason}. Source IP: {source_ip}"
        )


def reset_failed_attempts(account: str):
    """Reset failed attempts counter on successful request."""
    if account in _failed_attempts:
        del _failed_attempts[account]


# =============================================================================
# Audit Logging
# =============================================================================

def audit_log(event_type: str, account: str, source_ip: str, extra: dict = None):
    """Log an audit event in structured format."""
    log_entry = {
        "event": event_type,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "account": account,
        "source_ip": source_ip,
    }
    if extra:
        log_entry.update(extra)

    logger.info(f"AUDIT: {json.dumps(log_entry)}")


# =============================================================================
# Alerting
# =============================================================================

def send_alert(alert_type: str, message: str):
    """Send alert to SNS topic."""
    if not sns_client or not ALERT_SNS_TOPIC:
        logger.warning(f"ALERT (no SNS): {alert_type} - {message}")
        return

    try:
        sns_client.publish(
            TopicArn=ALERT_SNS_TOPIC,
            Subject=f"Gatekeeper Alert: {alert_type}",
            Message=json.dumps({
                "alert_type": alert_type,
                "severity": "HIGH",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "message": message
            })
        )
        logger.info(f"Alert sent: {alert_type}")
    except Exception as e:
        logger.error(f"Failed to send alert: {e}")
