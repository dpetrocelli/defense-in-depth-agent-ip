#!/usr/bin/env bash
# =============================================================================
# Model Benchmark — Test detection rate across multiple Ollama models
# =============================================================================
# Usage: ./tools/model_benchmark.sh <model_name>
#
# Swaps the agent's MODEL_ID, restarts the container, and runs experiment 2.
# =============================================================================

set -euo pipefail

MODEL="${1:?Usage: $0 <model_name>}"
COMPOSE_FILE="local/docker-compose.multi-account.yml"
ENDPOINT="http://localhost:8080"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

cd "$PROJECT_DIR"

echo -e "${CYAN}━━━ Benchmarking model: ${MODEL} ━━━${NC}"

# Update MODEL_ID in .env
sed -i '/^MODEL_ID=/d' local/.env 2>/dev/null || true
echo "MODEL_ID=${MODEL}" >> local/.env
cp local/.env local/.env.multi 2>/dev/null || true

# Recreate agent with new model
echo -e "${GREEN}[bench]${NC} Restarting agent with MODEL_ID=${MODEL}..."
docker compose -f "$COMPOSE_FILE" up -d agent 2>&1 | tail -5

# Wait for agent
echo -e "${GREEN}[bench]${NC} Waiting for agent..."
ELAPSED=0
until curl -sf "${ENDPOINT}/health" > /dev/null 2>&1; do
    if [ "$ELAPSED" -ge 120 ]; then
        echo "Agent not healthy after 120s — aborting"
        exit 1
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
done

echo -e "${GREEN}[bench]${NC} Agent healthy. Running experiment 2..."

# Sanitize model name for filename
SAFE_NAME=$(echo "$MODEL" | tr ':/' '_')
OUTPUT="docs/EXP2_${SAFE_NAME}.json"

python3 tools/experiment_runner.py \
    --endpoint "$ENDPOINT" \
    --exp 2 \
    --output "$OUTPUT"

echo -e "\n${CYAN}━━━ Results for ${MODEL} saved to ${OUTPUT} ━━━${NC}"
