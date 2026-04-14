#!/usr/bin/env bash
# =============================================================================
# Cluster Detection Benchmark
# =============================================================================
# Deploys Ollama on K8s cluster nodes (knode09/knode10), pulls models,
# and runs the 42-attack detection corpus from Paper 2 against each
# model+GPU combination.
#
# Prerequisites:
#   - kubectl configured with access to dpetrocelli namespace
#   - K8s manifests in ../../../i+d/benchmark/k8s/
#   - experiment_runner.py + corpus in tools/
#
# Usage:
#   ./tools/cluster_detection_benchmark.sh
#
# Results saved to docs/EXP2_cluster_*.json
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="/home/dp-note/code/i+d/benchmark/k8s"
NAMESPACE="dpetrocelli"

# Models to test (same as paper 3 + gemma4)
MODELS=("gemma4:e4b" "llama3:8b" "mistral:7b")

# Node config: name, manifest, service, local_port, gpu_label
declare -A NODES
NODES[knode10_manifest]="ollama-dpetrocelli.yaml"
NODES[knode10_service]="ollama-bench"
NODES[knode10_port]="11436"
NODES[knode10_gpu]="RTX-4060"
NODES[knode09_manifest]="ollama-knode09.yaml"
NODES[knode09_service]="ollama-bench-3060"
NODES[knode09_port]="11438"
NODES[knode09_gpu]="RTX-3060"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()   { echo -e "${GREEN}[bench]${NC} $*"; }
warn()   { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()  { echo -e "${RED}[error]${NC} $*" >&2; }
header() { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

cleanup() {
    info "Cleaning up port-forwards..."
    kill $PF_PID_10 2>/dev/null || true
    kill $PF_PID_09 2>/dev/null || true
}
trap cleanup EXIT

cd "$PROJECT_DIR"

# -------------------------------------------------------------------------
# 1. Deploy Ollama pods to cluster
# -------------------------------------------------------------------------
header "Deploying Ollama to K8s cluster"

for node in knode10 knode09; do
    manifest="${NODES[${node}_manifest]}"
    service="${NODES[${node}_service]}"
    gpu="${NODES[${node}_gpu]}"

    info "Deploying to ${node} (${gpu})..."
    kubectl apply -f "${K8S_DIR}/${manifest}" -n "$NAMESPACE" 2>&1 | sed 's/^/  /'
done

# -------------------------------------------------------------------------
# 2. Wait for pods to be ready
# -------------------------------------------------------------------------
header "Waiting for pods to be ready"

for node in knode10 knode09; do
    service="${NODES[${node}_service]}"
    gpu="${NODES[${node}_gpu]}"

    info "Waiting for ${node} (${gpu})..."
    kubectl wait --for=condition=ready pod \
        -l "app=${service}" \
        -n "$NAMESPACE" \
        --timeout=120s 2>&1 | sed 's/^/  /' || {
        warn "${node} pod not ready after 120s — skipping"
        continue
    }
    info "${node} ready"
done

# -------------------------------------------------------------------------
# 3. Set up port forwarding
# -------------------------------------------------------------------------
header "Setting up port forwarding"

PF_PID_10=""
PF_PID_09=""

for node in knode10 knode09; do
    service="${NODES[${node}_service]}"
    port="${NODES[${node}_port]}"
    gpu="${NODES[${node}_gpu]}"

    info "Port-forwarding ${node} (${gpu}): localhost:${port} → svc/${service}:11434"
    kubectl port-forward "svc/${service}" "${port}:11434" -n "$NAMESPACE" &

    if [ "$node" = "knode10" ]; then
        PF_PID_10=$!
    else
        PF_PID_09=$!
    fi
done

# Wait for port forwards to be ready
sleep 3

for node in knode10 knode09; do
    port="${NODES[${node}_port]}"
    info "Testing connectivity to ${node} on port ${port}..."
    curl -sf "http://localhost:${port}/" > /dev/null 2>&1 && info "${node} reachable" || warn "${node} not reachable yet"
done

# -------------------------------------------------------------------------
# 4. Pull models on each node
# -------------------------------------------------------------------------
header "Pulling models on cluster nodes"

for node in knode10 knode09; do
    port="${NODES[${node}_port]}"
    gpu="${NODES[${node}_gpu]}"

    for model in "${MODELS[@]}"; do
        info "Pulling ${model} on ${node} (${gpu})..."

        # Check if model already exists
        EXISTS=$(curl -sf "http://localhost:${port}/api/tags" 2>/dev/null \
            | python3 -c "import sys,json; models=[m['name'] for m in json.load(sys.stdin).get('models',[])]; print('yes' if '${model}' in models else 'no')" 2>/dev/null || echo "no")

        if [ "$EXISTS" = "yes" ]; then
            info "  ${model} already present on ${node}"
        else
            curl -sf "http://localhost:${port}/api/pull" \
                -X POST -d "{\"name\":\"${model}\"}" \
                --max-time 600 > /dev/null 2>&1 && info "  ${model} pulled" || warn "  Failed to pull ${model} on ${node}"
        fi
    done
done

# -------------------------------------------------------------------------
# 5. Run detection benchmark on each node × model
# -------------------------------------------------------------------------
header "Running detection benchmarks"

# We need to point the agent at each cluster Ollama instance.
# Strategy: for each model × node, update the agent's MODEL_ID and
# OLLAMA_BASE_URL, restart, and run experiment 2.

RESULTS_SUMMARY=""

for node in knode10 knode09; do
    port="${NODES[${node}_port]}"
    gpu="${NODES[${node}_gpu]}"

    for model in "${MODELS[@]}"; do
        SAFE_NAME=$(echo "${model}_${gpu}" | tr ':/' '_')
        OUTPUT="docs/EXP2_cluster_${SAFE_NAME}.json"

        header "Testing ${model} on ${node} (${gpu})"

        # Update agent config to use this cluster node's Ollama
        sed -i "s|^MODEL_ID=.*|MODEL_ID=${model}|" local/.env
        # Point OLLAMA_BASE_URL to the port-forwarded cluster node
        # The agent runs in Docker, so it needs host.docker.internal
        sed -i '/^OLLAMA_BASE_URL=/d' local/.env
        echo "OLLAMA_BASE_URL=http://host.docker.internal:${port}" >> local/.env
        cp local/.env local/.env.multi

        # Recreate agent
        info "Restarting agent with ${model} → ${node}:${port}..."
        docker compose -f local/docker-compose.multi-account.yml up -d --force-recreate agent 2>&1 | tail -2

        # Wait for agent
        ELAPSED=0
        until curl -sf http://localhost:8080/health > /dev/null 2>&1; do
            if [ "$ELAPSED" -ge 120 ]; then
                warn "Agent not healthy — skipping ${model}@${node}"
                continue 2
            fi
            sleep 3
            ELAPSED=$((ELAPSED + 3))
        done
        info "Agent healthy"

        # Run experiment 2
        info "Running 42-attack corpus..."
        python3 tools/experiment_runner.py \
            --endpoint http://localhost:8080 \
            --exp 2 \
            --output "$OUTPUT" 2>&1 | tail -15

        # Extract summary
        if [ -f "$OUTPUT" ]; then
            DETECTION=$(python3 -c "import json; d=json.load(open('${OUTPUT}')); print(d['experiments']['detection']['summary']['detection_rate'])")
            FP=$(python3 -c "import json; d=json.load(open('${OUTPUT}')); print(d['experiments']['detection']['summary']['fp_rate'])")
            RESULTS_SUMMARY="${RESULTS_SUMMARY}\n  ${model} @ ${gpu}: Detection=${DETECTION}%, FP=${FP}%"
            info "Result: Detection=${DETECTION}%, FP=${FP}%"
        fi
    done
done

# -------------------------------------------------------------------------
# 6. Restore agent to local Ollama
# -------------------------------------------------------------------------
header "Restoring agent to local Ollama"

sed -i "s|^MODEL_ID=.*|MODEL_ID=llama3.2:1b|" local/.env
sed -i '/^OLLAMA_BASE_URL=/d' local/.env
echo "OLLAMA_BASE_URL=http://ollama:11434" >> local/.env
cp local/.env local/.env.multi

docker compose -f local/docker-compose.multi-account.yml up -d --force-recreate agent 2>&1 | tail -2

# -------------------------------------------------------------------------
# 7. Print summary
# -------------------------------------------------------------------------
header "BENCHMARK RESULTS SUMMARY"

echo -e "\n  Local results (CPU inference):"
echo "  llama3.2:1b      : Detection=59.5%, FP=0.0%"
echo "  gemma3:4b        : Detection=59.5%, FP=0.0%"
echo "  phi4-mini        : Detection=61.9%, FP=39.1%"
echo "  gemma4:e4b       : Detection=69.0%, FP=26.1%"

echo -e "\n  Cluster results (GPU inference):"
echo -e "$RESULTS_SUMMARY"

echo -e "\n  Cloud results (Amazon Nova Lite):"
echo "  nova-lite        : Detection=90.5%, FP=0.0%"

echo ""
info "Detailed results in docs/EXP2_cluster_*.json"
