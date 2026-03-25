#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="llama-server"
IMAGE_NAME="llama-server:latest"
PORT="${LLAMA_PORT:-8100}"
MODEL_DIR="/mnt/AIPool/models"

# Default model — override with MODEL_NAME env var
MODEL_NAME="${MODEL_NAME:-Qwen2.5-7B-Instruct-Q4_K_M.gguf}"

if sudo docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container $CONTAINER_NAME is already running"
    echo "Use ./stop-llama.sh to stop it first"
    exit 1
fi

sudo docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

if ! sudo docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
    echo "Building llama-server image..."
    sudo docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

echo "Starting llama-server on port $PORT with model $MODEL_NAME..."
echo "Models stored at $MODEL_DIR (TrueNAS AIPool dataset)"

sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --gpus all \
    --restart unless-stopped \
    -p "${PORT}:8100" \
    -v "${MODEL_DIR}:/models" \
    -e MODEL_NAME="$MODEL_NAME" \
    "$IMAGE_NAME"

echo "Waiting for container to start..."
sleep 5

if sudo docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container started. Waiting for server (model download + load may take a few minutes on first run)..."
    for i in $(seq 1 60); do
        if curl -sf http://localhost:${PORT}/v1/models > /dev/null 2>&1; then
            echo "llama-server is ready!"
            echo "  Models:     http://localhost:${PORT}/v1/models"
            echo "  Chat:       POST http://localhost:${PORT}/v1/chat/completions"
            echo ""
            echo "Test it:"
            echo "  curl http://localhost:${PORT}/v1/chat/completions \\"
            echo "    -H 'Content-Type: application/json' \\"
            echo "    -d '{\"model\":\"${MODEL_NAME}\",\"messages\":[{\"role\":\"user\",\"content\":\"Fix: i went store and buyed milk\"}]}'"
            exit 0
        fi
        sleep 5
    done
    echo "Service started but not ready yet (may still be downloading model). Check logs:"
    echo "  sudo docker logs -f $CONTAINER_NAME"
else
    echo "Failed to start llama-server"
    sudo docker logs "$CONTAINER_NAME"
    exit 1
fi
