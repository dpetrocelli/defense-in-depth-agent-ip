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
from datetime import datetime, timezone
import boto3
from strands import Agent, tool
from strands.models.bedrock import BedrockModel

from app.response_filter import filter_response, sanitize_user_input, get_defensive_prompt

logger = logging.getLogger(__name__)

# Feature flags
USE_GATEKEEPER = os.environ.get('USE_GATEKEEPER', 'true').lower() == 'true'
ENABLE_RESPONSE_FILTER = os.environ.get('ENABLE_RESPONSE_FILTER', 'true').lower() == 'true'


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

        # Fetch prompts via secure gatekeeper or fallback to direct access
        if USE_GATEKEEPER and gatekeeper_url:
            prompts = self._fetch_prompts_via_gatekeeper(gatekeeper_url)
        elif secret_arn:
            prompts = self._fetch_prompts_direct(secret_arn)
        else:
            raise ValueError("Either gatekeeper_url or secret_arn must be provided")

        # Apply defensive prompt additions to resist prompt injection
        base_prompt = prompts.get('system_prompt', '')
        self._system_prompt = get_defensive_prompt(base_prompt)
        self._system_prompt_raw = base_prompt  # Keep raw for response filtering
        self._instruction_prompt = prompts.get('instruction_prompt', '')
        logger.info("Prompts loaded into memory (with defensive additions)")

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
        - Input sanitization to reduce prompt injection risk
        - Response filtering to detect prompt leakage
        - System prompt never exposed to the user
        """
        try:
            # Sanitize user input to reduce prompt injection risk
            sanitized_message = sanitize_user_input(message)

            # Combine instruction prompt with user message if available
            full_message = sanitized_message
            if self._instruction_prompt:
                full_message = f"{self._instruction_prompt}\n\nUser: {sanitized_message}"

            # Call the Strands agent
            response = self._agent(full_message)
            response_text = str(response)

            # Filter response to detect prompt leakage
            if ENABLE_RESPONSE_FILTER:
                filtered_response, was_filtered = filter_response(
                    response_text,
                    self._system_prompt_raw
                )
                if was_filtered:
                    logger.warning(f"Response filtered due to potential prompt leakage")
                return filtered_response

            return response_text

        except Exception as e:
            logger.error(f"Error invoking Strands agent: {e}")
            raise
