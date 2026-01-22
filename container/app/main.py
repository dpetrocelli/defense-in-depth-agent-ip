"""
Strands Agent - Protected Mode
==============================
This agent fetches prompts from Secrets Manager at runtime.
The prompts are NEVER stored in the container image.
"""

import os
import secrets
import logging
from fastapi import FastAPI, HTTPException, Header, Depends
from pydantic import BaseModel
from app.agent import ProtectedAgent, DEMO_TOOLS

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Protected AI Agent",
    description="AI Agent with protected prompts",
    version="1.0.0"
)

# API Key for authentication (set via environment variable)
API_KEY = os.environ.get("API_KEY", "").strip() or None


async def verify_api_key(x_api_key: str = Header(None, alias="X-API-Key")):
    """Verify the API key if authentication is enabled."""
    if not API_KEY:
        # No API key configured, allow all requests (dev mode)
        return True

    if not x_api_key:
        raise HTTPException(
            status_code=401,
            detail="Missing API key. Provide X-API-Key header."
        )

    if not secrets.compare_digest(x_api_key, API_KEY):
        raise HTTPException(
            status_code=403,
            detail="Invalid API key"
        )

    return True

# Initialize agent on startup (fetches prompts from Secrets Manager)
agent: ProtectedAgent = None


class InvokeRequest(BaseModel):
    message: str
    session_id: str = "default"


class InvokeResponse(BaseModel):
    response: str
    session_id: str


@app.on_event("startup")
async def startup_event():
    """Initialize the agent on startup."""
    global agent

    # Configuration
    gatekeeper_url = os.environ.get("GATEKEEPER_URL")
    secret_arn = os.environ.get("PROMPT_SECRET_ARN")
    model_id = os.environ.get("MODEL_ID", "amazon.nova-lite-v1:0")
    region = os.environ.get("AWS_REGION", "us-east-1")
    use_gatekeeper = os.environ.get("USE_GATEKEEPER", "true").lower() == "true"

    # Validate configuration
    if use_gatekeeper and not gatekeeper_url:
        logger.warning("USE_GATEKEEPER=true but no GATEKEEPER_URL - falling back to direct access")
        use_gatekeeper = False

    if not use_gatekeeper and not secret_arn:
        raise ValueError("Either GATEKEEPER_URL or PROMPT_SECRET_ARN must be provided")

    logger.info(f"Initializing agent with model {model_id}")
    logger.info(f"Security mode: {'Gatekeeper' if use_gatekeeper else 'Direct Secrets Manager'}")

    agent = ProtectedAgent(
        secret_arn=secret_arn if not use_gatekeeper else None,
        gatekeeper_url=gatekeeper_url if use_gatekeeper else None,
        model_id=model_id,
        region=region
    )
    logger.info("Agent initialized successfully")


@app.get("/health")
async def health_check():
    """Health check endpoint for ECS."""
    return {"status": "healthy"}


@app.get("/tools")
async def list_tools():
    """
    List available tools in this Strands agent.

    This demonstrates that this is a real Strands agent with tool-calling capabilities.
    """
    tools_info = []
    for tool_func in DEMO_TOOLS:
        tools_info.append({
            "name": tool_func.__name__,
            "description": tool_func.__doc__.strip().split('\n')[0] if tool_func.__doc__ else "No description"
        })

    return {
        "agent": "Strands SDK",
        "model": "amazon.nova-lite-v1:0",
        "tools_count": len(DEMO_TOOLS),
        "tools": tools_info
    }


@app.post("/invoke", response_model=InvokeResponse)
async def invoke_agent(request: InvokeRequest, _: bool = Depends(verify_api_key)):
    """
    Invoke the AI agent with a message.

    Requires X-API-Key header if API_KEY environment variable is set.
    The system prompt is fetched from Secrets Manager and never exposed.
    """
    if not agent:
        raise HTTPException(status_code=503, detail="Agent not initialized")

    try:
        response = await agent.invoke(
            message=request.message,
            session_id=request.session_id
        )
        return InvokeResponse(
            response=response,
            session_id=request.session_id
        )
    except Exception as e:
        logger.error(f"Error invoking agent: {e}")
        raise HTTPException(status_code=500, detail="Error processing request")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
