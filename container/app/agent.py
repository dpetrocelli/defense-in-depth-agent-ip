"""
Protected Agent Implementation
==============================
Uses Strands Agents SDK with prompts fetched via secure Gatekeeper.
Prompts are only held in memory, never persisted.

Security features:
- Prompts fetched via Lambda Gatekeeper with signed requests
- Embedded signing key prevents unauthorized access
- Response filtering detects and blocks prompt leakage
- Defensive prompt additions resist prompt injection

Includes demo tools to demonstrate Strands tool-calling capabilities.
"""

import os
import json
import logging
import hashlib
import urllib.request
from datetime import datetime, timezone
import boto3
from strands import Agent, tool
from strands.models.bedrock import BedrockModel

from app.response_filter import (
    filter_response,
    sanitize_user_input,
    get_defensive_prompt,
    validate_input_comprehensive,
    calculate_injection_risk
)

logger = logging.getLogger(__name__)

# Feature flags
USE_GATEKEEPER = os.environ.get('USE_GATEKEEPER', 'true').lower() == 'true'
ENABLE_RESPONSE_FILTER = os.environ.get('ENABLE_RESPONSE_FILTER', 'true').lower() == 'true'
ENABLE_PREFLIGHT_CHECK = os.environ.get('ENABLE_PREFLIGHT_CHECK', 'true').lower() == 'true'
ENABLE_WATERMARKING = os.environ.get('ENABLE_WATERMARKING', 'true').lower() == 'true'
ENABLE_INPUT_VALIDATION = os.environ.get('ENABLE_INPUT_VALIDATION', 'true').lower() == 'true'
BLOCK_HIGH_RISK_INPUTS = os.environ.get('BLOCK_HIGH_RISK_INPUTS', 'true').lower() == 'true'
CANARY_WEBHOOK_URL = os.environ.get('CANARY_WEBHOOK_URL', '')  # Optional: URL to ping if prompt leaks
EXPECTED_PROMPT_HASH = os.environ.get('EXPECTED_PROMPT_HASH', '')  # Optional: hash to validate prompts weren't tampered


# =============================================================================
# Security: Pre-flight Compliance Check
# =============================================================================

def check_bedrock_logging_disabled() -> bool:
    """
    Check if Bedrock model invocation logging is enabled in this account.
    If enabled, refuse to start - prompts would be exposed.

    Returns:
        True if safe (logging disabled), False if unsafe (logging enabled)
    """
    try:
        bedrock_client = boto3.client('bedrock')
        response = bedrock_client.get_model_invocation_logging_configuration()

        logging_config = response.get('loggingConfig', {})

        # Check if any logging is enabled
        cloudwatch_enabled = logging_config.get('cloudWatchConfig', {}).get('logGroupName')
        s3_enabled = logging_config.get('s3Config', {}).get('bucketName')

        if cloudwatch_enabled or s3_enabled:
            logger.error("SECURITY VIOLATION: Bedrock model invocation logging is ENABLED!")
            logger.error(f"CloudWatch: {cloudwatch_enabled}, S3: {s3_enabled}")
            logger.error("Refusing to start - prompts would be exposed to logs")
            return False

        logger.info("Pre-flight check PASSED: Bedrock logging is disabled")
        return True

    except Exception as e:
        # If we can't check, log warning but continue (might not have permission)
        logger.warning(f"Could not verify Bedrock logging status: {e}")
        logger.warning("Continuing with caution - ensure logging is disabled")
        return True  # Don't block if we can't check


# =============================================================================
# Security: Canary Token
# =============================================================================

def generate_canary_token(account_id: str) -> str:
    """
    Generate a unique canary token that will be embedded in the prompt.
    If this token appears anywhere outside the system, we know the prompt leaked.
    """
    # Create a unique, trackable token
    token_data = f"canary:{account_id}:{datetime.now().isoformat()}"
    token_hash = hashlib.sha256(token_data.encode()).hexdigest()[:16]

    canary = f"<!--CANARY-{token_hash}-->"
    return canary


# =============================================================================
# Security: Response Watermarking
# =============================================================================

def generate_watermark(account_id: str, session_id: str, request_id: str) -> str:
    """
    Generate an invisible watermark to embed in responses.
    This helps trace the origin of leaked content.

    Uses zero-width characters that are invisible but can be decoded.
    """
    # Create payload with tracking info
    payload = f"{account_id}:{session_id}:{request_id}"
    payload_hash = hashlib.sha256(payload.encode()).hexdigest()[:8]

    # Encode as zero-width characters (invisible in most displays)
    # Using: \u200b (zero-width space), \u200c (zero-width non-joiner), \u200d (zero-width joiner)
    watermark = ""
    char_map = {'0': '\u200b', '1': '\u200c', '2': '\u200d', '3': '\u200b\u200b',
                '4': '\u200b\u200c', '5': '\u200b\u200d', '6': '\u200c\u200b',
                '7': '\u200c\u200c', '8': '\u200c\u200d', '9': '\u200d\u200b',
                'a': '\u200d\u200c', 'b': '\u200d\u200d', 'c': '\u200b\u200b\u200b',
                'd': '\u200b\u200b\u200c', 'e': '\u200b\u200b\u200d', 'f': '\u200b\u200c\u200b'}

    for char in payload_hash:
        watermark += char_map.get(char, '')

    return watermark


def decode_watermark(text: str) -> str:
    """
    Decode a watermark from text (for forensic analysis).
    Returns the hash that can be correlated with logs.
    """
    # Reverse mapping
    char_map = {'\u200b': '0', '\u200c': '1', '\u200d': '2', '\u200b\u200b': '3',
                '\u200b\u200c': '4', '\u200b\u200d': '5', '\u200c\u200b': '6',
                '\u200c\u200c': '7', '\u200c\u200d': '8', '\u200d\u200b': '9',
                '\u200d\u200c': 'a', '\u200d\u200d': 'b', '\u200b\u200b\u200b': 'c',
                '\u200b\u200b\u200c': 'd', '\u200b\u200b\u200d': 'e', '\u200b\u200c\u200b': 'f'}

    decoded = ""
    i = 0
    while i < len(text):
        # Try 3-char sequences first, then 2-char, then 1-char
        for length in [3, 2, 1]:
            seq = text[i:i+length]
            if seq in char_map:
                decoded += char_map[seq]
                i += length
                break
        else:
            i += 1

    return decoded


# =============================================================================
# Security: Prompt Hash Validation
# =============================================================================

def compute_prompt_hash(prompts: dict) -> str:
    """
    Compute a hash of the prompts for integrity validation.
    This helps detect if prompts were tampered with during transit.
    """
    # Normalize and hash the prompts
    system = prompts.get('system_prompt', '')
    instruction = prompts.get('instruction_prompt', '')
    combined = f"{system}|{instruction}"
    return hashlib.sha256(combined.encode()).hexdigest()[:16]


def validate_prompt_hash(prompts: dict, expected_hash: str) -> bool:
    """
    Validate that prompts match the expected hash.
    Returns True if valid, False if tampered.
    """
    if not expected_hash:
        logger.warning("No expected prompt hash configured - skipping validation")
        return True

    actual_hash = compute_prompt_hash(prompts)

    if actual_hash != expected_hash:
        logger.error(f"SECURITY: Prompt hash mismatch! Expected {expected_hash}, got {actual_hash}")
        logger.error("Prompts may have been tampered with during transit!")
        return False

    logger.info("Prompt hash validation PASSED")
    return True


def report_canary_leak(canary_token: str, context: str = "unknown"):
    """
    Report if a canary token is detected in output (potential leak).
    """
    if not CANARY_WEBHOOK_URL:
        logger.warning(f"CANARY LEAK DETECTED but no webhook configured: {canary_token}")
        return

    try:
        data = json.dumps({
            "alert": "CANARY_LEAK_DETECTED",
            "canary_token": canary_token,
            "context": context,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }).encode('utf-8')

        req = urllib.request.Request(
            CANARY_WEBHOOK_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req, timeout=5)
        logger.warning(f"Canary leak reported to webhook")
    except Exception as e:
        logger.error(f"Failed to report canary leak: {e}")


# =============================================================================
# Demo Tools - Demonstrate Strands tool-calling capabilities
# =============================================================================

@tool
def calculator(operation: str, a: float, b: float) -> str:
    """
    Perform basic mathematical calculations.

    Args:
        operation: The operation to perform (add, subtract, multiply, divide, power, modulo)
        a: First number
        b: Second number

    Returns:
        The result of the calculation as a string
    """
    operations = {
        "add": lambda x, y: x + y,
        "subtract": lambda x, y: x - y,
        "multiply": lambda x, y: x * y,
        "divide": lambda x, y: x / y if y != 0 else "Error: Division by zero",
        "power": lambda x, y: x ** y,
        "modulo": lambda x, y: x % y if y != 0 else "Error: Modulo by zero",
    }

    if operation not in operations:
        return f"Error: Unknown operation '{operation}'. Available: {list(operations.keys())}"

    result = operations[operation](a, b)
    return f"{a} {operation} {b} = {result}"


@tool
def get_current_time(timezone_name: str = "UTC") -> str:
    """
    Get the current date and time.

    Args:
        timezone_name: Timezone name (only UTC supported for simplicity)

    Returns:
        Current date and time as a formatted string
    """
    now = datetime.now(timezone.utc)
    return f"Current time (UTC): {now.strftime('%Y-%m-%d %H:%M:%S')}"


@tool
def string_utils(operation: str, text: str) -> str:
    """
    Perform string utility operations.

    Args:
        operation: The operation (reverse, uppercase, lowercase, length, word_count)
        text: The text to operate on

    Returns:
        Result of the string operation
    """
    operations = {
        "reverse": lambda t: t[::-1],
        "uppercase": lambda t: t.upper(),
        "lowercase": lambda t: t.lower(),
        "length": lambda t: f"Length: {len(t)} characters",
        "word_count": lambda t: f"Word count: {len(t.split())} words",
    }

    if operation not in operations:
        return f"Error: Unknown operation '{operation}'. Available: {list(operations.keys())}"

    return operations[operation](text)


@tool
def fibonacci(n: int) -> str:
    """
    Calculate the nth Fibonacci number.

    Args:
        n: Which Fibonacci number to calculate (1-indexed, max 50)

    Returns:
        The nth Fibonacci number
    """
    if n < 1:
        return "Error: n must be >= 1"
    if n > 50:
        return "Error: n must be <= 50 (to prevent timeout)"

    if n <= 2:
        return f"Fibonacci({n}) = 1"

    a, b = 1, 1
    for _ in range(n - 2):
        a, b = b, a + b

    return f"Fibonacci({n}) = {b}"


# List of all tools to register with the agent
DEMO_TOOLS = [calculator, get_current_time, string_utils, fibonacci]


class ProtectedAgent:
    """
    AI Agent with protected prompts using Strands SDK.

    Security architecture:
    - Prompts fetched via Lambda Gatekeeper (requires signed request)
    - Signing key embedded in container image (not extractable)
    - Response filtering detects prompt leakage attempts
    - Defensive prompts resist prompt injection

    The system prompt is held only in memory, never logged or exposed.
    """

    def __init__(
        self,
        secret_arn: str = None,
        gatekeeper_url: str = None,
        model_id: str = "amazon.nova-lite-v1:0",
        region: str = "us-east-1"
    ):
        self.model_id = model_id
        self.region = region

        # =================================================================
        # SECURITY: Pre-flight compliance check
        # =================================================================
        if ENABLE_PREFLIGHT_CHECK:
            if not check_bedrock_logging_disabled():
                raise RuntimeError(
                    "SECURITY VIOLATION: Bedrock model invocation logging is enabled. "
                    "Refusing to start agent - prompts would be exposed. "
                    "Disable Bedrock logging before starting the agent."
                )

        # Fetch prompts via secure gatekeeper or fallback to direct access
        if USE_GATEKEEPER and gatekeeper_url:
            prompts = self._fetch_prompts_via_gatekeeper(gatekeeper_url)
        elif secret_arn:
            prompts = self._fetch_prompts_direct(secret_arn)
        else:
            raise ValueError("Either gatekeeper_url or secret_arn must be provided")

        # =================================================================
        # SECURITY: Validate prompt integrity (detect tampering)
        # =================================================================
        if EXPECTED_PROMPT_HASH:
            if not validate_prompt_hash(prompts, EXPECTED_PROMPT_HASH):
                raise RuntimeError(
                    "SECURITY VIOLATION: Prompt hash validation failed! "
                    "Prompts may have been tampered with during transit."
                )

        # =================================================================
        # SECURITY: Generate and embed canary token
        # =================================================================
        try:
            sts = boto3.client('sts')
            account_id = sts.get_caller_identity()['Account']
        except Exception:
            account_id = "unknown"

        self._canary_token = generate_canary_token(account_id)

        # Apply defensive prompt additions to resist prompt injection
        base_prompt = prompts.get('system_prompt', '')

        # Embed canary token in prompt (invisible to users but trackable if leaked)
        prompt_with_canary = f"{self._canary_token}\n{base_prompt}\n{self._canary_token}"

        self._system_prompt = get_defensive_prompt(prompt_with_canary)
        self._system_prompt_raw = base_prompt  # Keep raw for response filtering
        self._instruction_prompt = prompts.get('instruction_prompt', '')
        self._request_counter = 0  # For generating unique request IDs
        logger.info("Prompts loaded into memory (with defensive additions + canary)")

        # Initialize the Strands agent with Bedrock model
        self._agent = self._create_agent()
        logger.info("Strands agent initialized")

    def _fetch_prompts_via_gatekeeper(self, gatekeeper_url: str) -> dict:
        """
        Fetch prompts via the secure Lambda Gatekeeper.

        This is the secure method that validates the container's identity
        using an embedded signing key.
        """
        try:
            from app.gatekeeper_client import GatekeeperClient

            client = GatekeeperClient(gatekeeper_url)
            prompts = client.fetch_prompts()
            logger.info("Prompts fetched via secure gatekeeper")
            return prompts

        except Exception as e:
            logger.error(f"Failed to fetch prompts via gatekeeper: {e}")
            raise RuntimeError("Cannot initialize agent: gatekeeper unavailable")

    def _fetch_prompts_direct(self, secret_arn: str) -> dict:
        """
        Fetch prompts directly from Secrets Manager.

        This is the fallback method for development/testing.
        In production, use the gatekeeper for better security.
        """
        try:
            logger.warning("Using direct Secrets Manager access (less secure)")
            secrets_client = boto3.client(
                'secretsmanager',
                region_name=self.region
            )

            response = secrets_client.get_secret_value(SecretId=secret_arn)
            return json.loads(response['SecretString'])

        except Exception as e:
            logger.error(f"Failed to fetch prompts from Secrets Manager: {e}")
            raise RuntimeError("Cannot initialize agent: prompts unavailable")

    def _create_agent(self) -> Agent:
        """Create a Strands agent with the protected system prompt and tools."""
        # Configure Bedrock model
        model = BedrockModel(
            model_id=self.model_id,
            region_name=self.region
        )

        # Create agent with system prompt (never exposed) and demo tools
        agent = Agent(
            model=model,
            system_prompt=self._system_prompt,
            tools=DEMO_TOOLS  # Register demo tools for tool-calling
        )

        logger.info(f"Agent created with {len(DEMO_TOOLS)} tools: {[t.__name__ for t in DEMO_TOOLS]}")

        return agent

    async def invoke(
        self,
        message: str,
        session_id: str = "default"
    ) -> str:
        """
        Invoke the agent with a user message.

        Security measures:
        - Comprehensive input validation (OWASP + AWS best practices)
        - Risk-based blocking of high/critical risk inputs
        - Input sanitization to reduce prompt injection risk
        - Response filtering to detect prompt leakage
        - Response watermarking for leak tracing
        - System prompt never exposed to the user
        """
        try:
            # Generate unique request ID for this invocation
            self._request_counter += 1
            request_id = f"{session_id}-{self._request_counter}-{datetime.now().timestamp()}"

            # Log request for audit trail (watermark correlation)
            try:
                sts = boto3.client('sts')
                account_id = sts.get_caller_identity()['Account']
            except Exception:
                account_id = "unknown"

            logger.info(f"AUDIT: Request {request_id} from account {account_id}, session {session_id}")

            # =================================================================
            # SECURITY: Comprehensive input validation (before any processing)
            # =================================================================
            if ENABLE_INPUT_VALIDATION:
                validation = validate_input_comprehensive(message)

                logger.info(f"Input validation: risk_level={validation['risk_level']}, "
                           f"score={validation.get('risk_score', 0)}, issues={len(validation['issues'])}")

                # Block high-risk and critical-risk inputs
                if BLOCK_HIGH_RISK_INPUTS and validation['risk_level'] in ['critical', 'high']:
                    logger.warning(f"BLOCKED: High-risk input detected. "
                                  f"Level: {validation['risk_level']}, "
                                  f"Indicators: {validation['issues']}")
                    return "I'm happy to help with other questions!"

                # Log medium-risk inputs but allow them through
                if validation['risk_level'] == 'medium':
                    logger.warning(f"SUSPICIOUS: Medium-risk input. Indicators: {validation['issues']}")

            # Sanitize user input to reduce prompt injection risk
            sanitized_message = sanitize_user_input(message)

            # Combine instruction prompt with user message if available
            full_message = sanitized_message
            if self._instruction_prompt:
                full_message = f"{self._instruction_prompt}\n\nUser: {sanitized_message}"

            # Call the Strands agent
            response = self._agent(full_message)
            response_text = str(response)

            # =================================================================
            # SECURITY: Check for canary token leak
            # =================================================================
            if self._canary_token and self._canary_token in response_text:
                logger.error("CRITICAL: Canary token detected in response - PROMPT LEAKED!")
                report_canary_leak(self._canary_token, "model_response")
                return "I'm happy to help with other questions!"

            # Filter response to detect prompt leakage
            if ENABLE_RESPONSE_FILTER:
                filtered_response, was_filtered = filter_response(
                    response_text,
                    self._system_prompt_raw
                )
                if was_filtered:
                    logger.warning(f"Response filtered due to potential prompt leakage")
                response_text = filtered_response

            # =================================================================
            # SECURITY: Add invisible watermark to response
            # =================================================================
            if ENABLE_WATERMARKING:
                watermark = generate_watermark(account_id, session_id, request_id)
                # Insert watermark at strategic points (harder to strip)
                response_text = f"{watermark}{response_text}{watermark}"
                logger.debug(f"Response watermarked for request {request_id}")

            return response_text

        except Exception as e:
            logger.error(f"Error invoking Strands agent: {e}")
            raise
