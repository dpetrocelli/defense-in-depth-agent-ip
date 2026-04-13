# =============================================================================
# MULTI-STAGE BUILD FOR LAMBDA CONTAINER
# =============================================================================
# Uses AWS Lambda Python base image for native Lambda support.
# The signing key is injected via BuildKit secrets — it never appears in any
# image layer, build arg, or docker history.
#
# Build command:
#   docker buildx build --secret id=signing_key,src=.signing_key -t agent .
# =============================================================================

# syntax=docker/dockerfile:1

FROM public.ecr.aws/lambda/python:3.12

# Install dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy application code
COPY app/ ${LAMBDA_TASK_ROOT}/app/

# =============================================================================
# SECURITY: Inject signing key via BuildKit secret mount
# =============================================================================
# The key is mounted only during this RUN step and never persisted to any
# layer. Unlike ARG/ENV or multi-stage COPY, it cannot be recovered from
# docker history, image inspect, or layer tarballs.
RUN --mount=type=secret,id=signing_key \
    cp /run/secrets/signing_key ${LAMBDA_TASK_ROOT}/.signing_key && \
    chmod 444 ${LAMBDA_TASK_ROOT}/.signing_key

# Set the Lambda handler
CMD ["app.main.handler"]
