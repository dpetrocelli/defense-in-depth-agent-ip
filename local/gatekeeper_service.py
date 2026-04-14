"""
Gatekeeper Service — Local Multi-Account Simulation
====================================================
FastAPI wrapper around the Lambda gatekeeper logic.
Simulates the central account's API Gateway + Lambda.

Validates HMAC-SHA256 signed requests from the agent (client account),
fetches prompts from Secrets Manager, and publishes security alerts to SNS.

All security features from the production Lambda are preserved:
  - HMAC signature validation
  - Timestamp validation (5 min window)
  - Nonce tracking (replay prevention)
  - Rate limiting per account
  - Audit logging
  - SNS alerting on suspicious activity (L4 cross-account events)
"""

import hashlib
import hmac
import json
import logging
import os
import time
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Gatekeeper Service", version="1.0.0")

# ---------------------------------------------------------------------------
# Configuration (mirrors Lambda environment variables)
# ---------------------------------------------------------------------------
SIGNING_KEY = os.environ.get("SIGNING_KEY", "")
PROMPT_SECRET_ARN = os.environ.get("PROMPT_SECRET_ARN", "")
ALLOWED_CLIENT_ACCOUNTS = [
    a.strip()
    for a in os.environ.get("ALLOWED_CLIENT_ACCOUNTS", "").split(",")
    if a.strip()
]
ALERT_SNS_TOPIC = os.environ.get("ALERT_SNS_TOPIC", "")
REQUEST_TIMEOUT_SECONDS = 300
MAX_REQUESTS_PER_MINUTE = int(os.environ.get("MAX_REQUESTS_PER_MINUTE", "60"))

# In-memory tracking (same as Lambda — resets on restart)
_nonce_cache: dict[str, int] = {}
_rate_limit_cache: dict[str, list[float]] = {}
_failed_attempts: dict[str, int] = {}

# Lazy-init boto3 clients
_secrets_client = None
_sns_client = None


def secrets_client():
    global _secrets_client
    if _secrets_client is None:
        _secrets_client = boto3.client(
            "secretsmanager",
            region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
        )
    return _secrets_client


def sns_client():
    global _sns_client
    if _sns_client is None and ALERT_SNS_TOPIC:
        _sns_client = boto3.client(
            "sns",
            region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
        )
    return _sns_client


# =========================================================================
# Security: Signature Generation & Validation
# =========================================================================


def generate_signature(
    timestamp: str, nonce: str, client_account: str, body_hash: str = ""
) -> str:
    if body_hash:
        message = f"{timestamp}:{nonce}:{client_account}:{body_hash}"
    else:
        message = f"{timestamp}:{nonce}:{client_account}"
    return hmac.new(
        key=SIGNING_KEY.encode("utf-8"),
        msg=message.encode("utf-8"),
        digestmod=hashlib.sha256,
    ).hexdigest()


# =========================================================================
# Security: Rate Limiting
# =========================================================================


def check_rate_limit(account: str) -> bool:
    current_time = time.time()
    one_minute_ago = current_time - 60
    if account in _rate_limit_cache:
        _rate_limit_cache[account] = [
            ts for ts in _rate_limit_cache[account] if ts > one_minute_ago
        ]
    else:
        _rate_limit_cache[account] = []
    if len(_rate_limit_cache[account]) >= MAX_REQUESTS_PER_MINUTE:
        return False
    _rate_limit_cache[account].append(current_time)
    return True


# =========================================================================
# Security: Nonce Validation
# =========================================================================


def validate_nonce(nonce: str, timestamp: int) -> bool:
    current_time = time.time()
    expired_before = current_time - REQUEST_TIMEOUT_SECONDS - 60
    expired_nonces = [n for n, ts in _nonce_cache.items() if ts < expired_before]
    for n in expired_nonces:
        del _nonce_cache[n]
    if nonce in _nonce_cache:
        return False
    _nonce_cache[nonce] = timestamp
    return True


# =========================================================================
# Security: Failed Attempts & Alerting
# =========================================================================


def record_failed_attempt(account: str, reason: str, source_ip: str):
    if account not in _failed_attempts:
        _failed_attempts[account] = 0
    _failed_attempts[account] += 1
    logger.warning(
        f"Failed attempt #{_failed_attempts[account]} from {account}: {reason}"
    )
    if _failed_attempts[account] >= 5:
        send_alert(
            "MULTIPLE_FAILED_ATTEMPTS",
            f"Account {account} has {_failed_attempts[account]} failed attempts. "
            f"Latest reason: {reason}. Source IP: {source_ip}",
        )


def reset_failed_attempts(account: str):
    _failed_attempts.pop(account, None)


def send_alert(alert_type: str, message: str):
    client = sns_client()
    if not client or not ALERT_SNS_TOPIC:
        logger.warning(f"ALERT (no SNS): {alert_type} - {message}")
        return
    try:
        client.publish(
            TopicArn=ALERT_SNS_TOPIC,
            Subject=f"Gatekeeper Alert: {alert_type}",
            Message=json.dumps(
                {
                    "alert_type": alert_type,
                    "severity": "HIGH",
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "message": message,
                }
            ),
        )
        logger.info(f"Alert sent to SNS: {alert_type}")
    except Exception as e:
        logger.error(f"Failed to send alert: {e}")


# =========================================================================
# Audit Logging
# =========================================================================


def audit_log(event_type: str, account: str, source_ip: str, extra: dict = None):
    log_entry = {
        "event": event_type,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "account": account,
        "source_ip": source_ip,
    }
    if extra:
        log_entry.update(extra)
    logger.info(f"AUDIT: {json.dumps(log_entry)}")


# =========================================================================
# Prompt Retrieval
# =========================================================================


def get_prompts() -> dict:
    try:
        response = secrets_client().get_secret_value(SecretId=PROMPT_SECRET_ARN)
        prompts = json.loads(response["SecretString"])
        # Add integrity hash for client-side validation
        system = prompts.get("system_prompt", "")
        instruction = prompts.get("instruction_prompt", "")
        combined = f"{system}|{instruction}"
        prompts["_integrity_hash"] = hashlib.sha256(combined.encode()).hexdigest()[:16]
        return prompts
    except ClientError as e:
        logger.error(f"Failed to fetch prompts: {e}")
        raise


# =========================================================================
# Endpoints
# =========================================================================


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "service": "gatekeeper",
        "allowed_accounts": ALLOWED_CLIENT_ACCOUNTS,
        "has_signing_key": bool(SIGNING_KEY),
        "has_secret_arn": bool(PROMPT_SECRET_ARN),
    }


@app.post("/prompts")
async def fetch_prompts(request: Request):
    """
    Main gatekeeper endpoint — validates HMAC-signed requests and returns prompts.
    Mirrors the Lambda handler logic exactly.
    """
    source_ip = request.client.host if request.client else "unknown"

    # Extract headers
    signature = request.headers.get("x-signature", "")
    timestamp = request.headers.get("x-timestamp", "")
    nonce = request.headers.get("x-nonce", "")
    client_account = request.headers.get("x-client-account", "")
    body_hash = request.headers.get("x-body-hash", "")

    # Audit log
    audit_log(
        "REQUEST",
        client_account,
        source_ip,
        {
            "has_signature": bool(signature),
            "has_timestamp": bool(timestamp),
            "has_nonce": bool(nonce),
        },
    )

    # Validate required headers
    if not all([signature, timestamp, nonce, client_account]):
        record_failed_attempt(client_account or "unknown", "missing_headers", source_ip)
        return JSONResponse(
            status_code=400, content={"error": "Missing required headers"}
        )

    # Validate client account
    if client_account not in ALLOWED_CLIENT_ACCOUNTS:
        record_failed_attempt(client_account, "unauthorized_account", source_ip)
        audit_log("UNAUTHORIZED_ACCOUNT", client_account, source_ip)
        return JSONResponse(
            status_code=403, content={"error": "Unauthorized client account"}
        )

    # Rate limiting
    if not check_rate_limit(client_account):
        record_failed_attempt(client_account, "rate_limited", source_ip)
        audit_log("RATE_LIMITED", client_account, source_ip)
        return JSONResponse(status_code=429, content={"error": "Rate limit exceeded"})

    # Timestamp validation
    try:
        request_time = int(timestamp)
        current_time = int(time.time())
        if abs(current_time - request_time) > REQUEST_TIMEOUT_SECONDS:
            record_failed_attempt(client_account, "expired_timestamp", source_ip)
            return JSONResponse(status_code=403, content={"error": "Request expired"})
    except ValueError:
        record_failed_attempt(client_account, "invalid_timestamp", source_ip)
        return JSONResponse(
            status_code=400, content={"error": "Invalid timestamp format"}
        )

    # Nonce validation (replay prevention)
    if not validate_nonce(nonce, request_time):
        record_failed_attempt(client_account, "replay_attack", source_ip)
        audit_log("REPLAY_ATTEMPT", client_account, source_ip, {"nonce": nonce[:8]})
        return JSONResponse(
            status_code=403,
            content={"error": "Nonce already used (replay attack detected)"},
        )

    # HMAC signature validation
    expected_signature = generate_signature(timestamp, nonce, client_account, body_hash)
    if not hmac.compare_digest(signature, expected_signature):
        record_failed_attempt(client_account, "invalid_signature", source_ip)
        audit_log("INVALID_SIGNATURE", client_account, source_ip)
        return JSONResponse(status_code=403, content={"error": "Invalid signature"})

    # Body integrity check
    if body_hash:
        body = await request.body()
        actual_body_hash = hashlib.sha256(body).hexdigest()[:16]
        if body_hash != actual_body_hash:
            record_failed_attempt(client_account, "body_tampered", source_ip)
            audit_log("BODY_TAMPERED", client_account, source_ip)
            return JSONResponse(
                status_code=403,
                content={"error": "Request body integrity check failed"},
            )

    # SUCCESS
    audit_log("SUCCESS", client_account, source_ip)
    reset_failed_attempts(client_account)

    try:
        prompts = get_prompts()
        return JSONResponse(status_code=200, content=prompts)
    except Exception as e:
        logger.error(f"Failed to retrieve prompts: {e}")
        return JSONResponse(status_code=500, content={"error": "Internal server error"})


@app.get("/stats")
async def stats():
    """Diagnostic endpoint — shows security counters."""
    return {
        "nonce_cache_size": len(_nonce_cache),
        "rate_limit_accounts": list(_rate_limit_cache.keys()),
        "failed_attempts": dict(_failed_attempts),
    }
