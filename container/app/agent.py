"""
Protected Agent Implementation
==============================
Uses Strands Agents SDK with prompts fetched from Secrets Manager.
Prompts are only held in memory, never persisted.

Includes demo tools to demonstrate Strands tool-calling capabilities.
"""

import json
import logging
import math
from datetime import datetime, timezone
import boto3
from strands import Agent, tool
from strands.models.bedrock import BedrockModel

logger = logging.getLogger(__name__)


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

    The system prompt is fetched from AWS Secrets Manager at initialization
    and held only in memory. It is never logged, persisted, or exposed.
    """

    def __init__(
        self,
        secret_arn: str,
        model_id: str = "amazon.nova-lite-v1:0",
        region: str = "us-east-1"
    ):
        self.model_id = model_id
        self.region = region

        # Fetch prompt from Secrets Manager (cross-account)
        # This is the ONLY place the prompt exists - in memory
        prompts = self._fetch_prompts(secret_arn)
        self._system_prompt = prompts.get('system_prompt', '')
        self._instruction_prompt = prompts.get('instruction_prompt', '')
        logger.info("Prompts loaded into memory from Secrets Manager")

        # Initialize the Strands agent with Bedrock model
        self._agent = self._create_agent()
        logger.info("Strands agent initialized")

    def _fetch_prompts(self, secret_arn: str) -> dict:
        """
        Fetch prompts from Secrets Manager.

        The secret is in a different AWS account (central account).
        Access is granted via cross-account IAM role.
        """
        try:
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

        The system prompt is used internally but never exposed to the user.
        """
        try:
            # Combine instruction prompt with user message if available
            full_message = message
            if self._instruction_prompt:
                full_message = f"{self._instruction_prompt}\n\nUser: {message}"

            # Call the Strands agent
            response = self._agent(full_message)

            return str(response)

        except Exception as e:
            logger.error(f"Error invoking Strands agent: {e}")
            raise
