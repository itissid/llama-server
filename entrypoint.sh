#!/bin/bash
set -e

MODEL_PATH="${MODEL_PATH:-/models}"
MODEL_NAME="${MODEL_NAME:-Qwen2.5-7B-Instruct-Q4_K_M.gguf}"

# Known models and their HuggingFace repos
declare -A MODEL_REPOS=(
    ["Qwen2.5-7B-Instruct-Q4_K_M.gguf"]="bartowski/Qwen2.5-7B-Instruct-GGUF"
    ["Qwen3-8B-Q4_K_M.gguf"]="Qwen/Qwen3-8B-GGUF"
    ["Llama-3.2-3B-Instruct-Q4_K_M.gguf"]="bartowski/Llama-3.2-3B-Instruct-GGUF"
)

# Download model if missing
if [ ! -f "${MODEL_PATH}/${MODEL_NAME}" ]; then
    REPO="${MODEL_REPOS[$MODEL_NAME]}"
    if [ -z "$REPO" ]; then
        echo "ERROR: Model not found: ${MODEL_PATH}/${MODEL_NAME}"
        echo "Unknown model — download it manually to ${MODEL_PATH}/"
        exit 1
    fi
    echo "Model not found. Downloading ${MODEL_NAME} from ${REPO}..."
    python3.12 -c "
from huggingface_hub import hf_hub_download
hf_hub_download(repo_id='${REPO}', filename='${MODEL_NAME}', local_dir='${MODEL_PATH}')
"
    if [ ! -f "${MODEL_PATH}/${MODEL_NAME}" ]; then
        echo "ERROR: Download failed."
        exit 1
    fi
    echo "Download complete."
fi

echo "Starting llama-cpp-python server with ${MODEL_NAME}..."
exec python3.12 -m llama_cpp.server \
    --model "${MODEL_PATH}/${MODEL_NAME}" \
    --host 0.0.0.0 \
    --port 8100 \
    --n_gpu_layers "${N_GPU_LAYERS:--1}" \
    --n_ctx "${N_CTX:-4096}" \
    --flash_attn true
