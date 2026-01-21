FROM python:3.13-slim

# Security: Create non-root user
RUN groupadd --gid 1000 appgroup && \
    useradd --uid 1000 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# Install dependencies as root (before switching user)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=appuser:appgroup app/ ./app/

# No prompts in the image - they are fetched at runtime from Secrets Manager

# Switch to non-root user
USER appuser

# Run the agent
EXPOSE 8080
CMD ["python", "-m", "app.main"]
