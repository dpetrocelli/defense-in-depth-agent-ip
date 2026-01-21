"""
Strands Agent - Protected Mode
==============================
This agent fetches prompts from Secrets Manager at runtime.
The prompts are NEVER stored in the container image.
"""

import os
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from app.agent import ProtectedAgent, DEMO_TOOLS

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Protected AI Agent",
    description="AI Agent with protected prompts",
    version="1.0.0"
)

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

    secret_arn = os.environ.get("PROMPT_SECRET_ARN")
    if not secret_arn:
        raise ValueError("PROMPT_SECRET_ARN environment variable is required")

    model_id = os.environ.get("MODEL_ID", "amazon.nova-lite-v1:0")
    region = os.environ.get("AWS_REGION", "us-east-1")

    logger.info(f"Initializing agent with model {model_id}")
    agent = ProtectedAgent(
        secret_arn=secret_arn,
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
async def invoke_agent(request: InvokeRequest):
    """
    Invoke the AI agent with a message.

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
