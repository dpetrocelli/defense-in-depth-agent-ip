# =============================================================================
# MULTI-STAGE BUILD FOR SECURITY
# =============================================================================
# The signing key is embedded in a secrets stage, then COPIED to the final image.
# This prevents the key from appearing in `docker history` output.
#
# If someone runs: docker history <image> --no-trunc
# They will see: COPY /secrets/.signing_key /app/.signing_key
# NOT the actual key value.

# -----------------------------------------------------------------------------
# Stage 1: Secrets - Create the signing key file
# -----------------------------------------------------------------------------
FROM alpine:3.19 AS secrets

ARG SIGNING_KEY=""

# Create the signing key file in an isolated stage
# This command will NOT appear in the final image's history
RUN mkdir -p /secrets && \
    echo "${SIGNING_KEY}" > /secrets/.signing_key && \
    chmod 400 /secrets/.signing_key

# -----------------------------------------------------------------------------
# Stage 2: Runtime - Final image
# -----------------------------------------------------------------------------
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

# =============================================================================
# SECURITY: Copy the signing key from secrets stage
# =============================================================================
# The key value is NOT visible in docker history because:
# 1. The echo command happened in a different stage (discarded)
# 2. Only the COPY command appears in this image's history
# 3. COPY doesn't reveal file contents in history
#
# docker history will show:
#   COPY /secrets/.signing_key /app/.signing_key
# NOT:
#   echo "actual-key-value" > /app/.signing_key
COPY --from=secrets --chown=appuser:appgroup /secrets/.signing_key /app/.signing_key

# No prompts in the image - they are fetched at runtime via Gatekeeper

# Switch to non-root user
USER appuser

# Run the agent
EXPOSE 8080
CMD ["python", "-m", "app.main"]
