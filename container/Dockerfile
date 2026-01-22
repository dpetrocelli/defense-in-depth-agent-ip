# =============================================================================
# MULTI-STAGE BUILD FOR LAMBDA CONTAINER
# =============================================================================
# Uses AWS Lambda Python base image for native Lambda support
# The signing key is embedded in a secrets stage to hide from docker history

# -----------------------------------------------------------------------------
# Stage 1: Secrets - Create the signing key file
# -----------------------------------------------------------------------------
FROM alpine:3.19 AS secrets

ARG SIGNING_KEY=""

# Create the signing key file in an isolated stage
# This command will NOT appear in the final image's history
RUN mkdir -p /secrets && \
    echo "${SIGNING_KEY}" > /secrets/.signing_key && \
    chmod 444 /secrets/.signing_key

# -----------------------------------------------------------------------------
# Stage 2: Runtime - AWS Lambda Python base image
# -----------------------------------------------------------------------------
FROM public.ecr.aws/lambda/python:3.12

# Install dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy application code
COPY app/ ${LAMBDA_TASK_ROOT}/app/

# =============================================================================
# SECURITY: Copy the signing key from secrets stage
# =============================================================================
# The key value is NOT visible in docker history because:
# 1. The echo command happened in a different stage (discarded)
# 2. Only the COPY command appears in this image's history
COPY --from=secrets /secrets/.signing_key ${LAMBDA_TASK_ROOT}/.signing_key

# Set the Lambda handler
# This points to the handler function in app/main.py
CMD ["app.main.handler"]
