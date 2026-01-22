#!/bin/bash
# =============================================================================
# Secure Container Build Script
# =============================================================================
# This script builds the container image with the signing key embedded.
#
# Usage:
#   ./build.sh <signing_key> <ecr_repo_url> <tag>
#
# Example:
#   ./build.sh "abc123..." "123456789.dkr.ecr.us-east-1.amazonaws.com/bedrock-protected-agent" "v1"
#
# The signing key should come from terraform output:
#   terraform output -raw gatekeeper_signing_key

set -e

SIGNING_KEY="${1}"
ECR_REPO="${2}"
TAG="${3:-latest}"

if [ -z "$SIGNING_KEY" ] || [ -z "$ECR_REPO" ]; then
    echo "Usage: $0 <signing_key> <ecr_repo_url> [tag]"
    echo ""
    echo "Get the signing key from terraform:"
    echo "  cd environments/central"
    echo "  terraform output -raw gatekeeper_signing_key"
    exit 1
fi

echo "=============================================="
echo "Building Protected Agent Container"
echo "=============================================="
echo "ECR Repository: $ECR_REPO"
echo "Tag: $TAG"
echo "Signing Key: [REDACTED - ${#SIGNING_KEY} chars]"
echo ""

# Build the image with signing key
echo "Building container image..."
docker build \
    --build-arg SIGNING_KEY="${SIGNING_KEY}" \
    -t "${ECR_REPO}:${TAG}" \
    .

echo ""
echo "=============================================="
echo "Build Complete!"
echo "=============================================="
echo ""
echo "To push to ECR:"
echo "  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REPO%/*}"
echo "  docker push ${ECR_REPO}:${TAG}"
echo ""
echo "IMPORTANT: The signing key is now embedded in this image."
echo "Only this exact image can authenticate with the gatekeeper."
