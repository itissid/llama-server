FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

RUN apt-get update && apt-get install -y software-properties-common curl \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y \
    python3.12 python3.12-venv python3.12-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt /app/requirements.txt

# Install pinned dependencies from requirements.txt
RUN python3.12 -m ensurepip && \
    python3.12 -m pip install --upgrade pip && \
    python3.12 -m pip install -r /app/requirements.txt \
    --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8100

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8100/v1/models || exit 1

ENV MODEL_PATH=/models
ENV MODEL_NAME=Qwen2.5-7B-Instruct-Q4_K_M.gguf
ENV N_GPU_LAYERS=-1
ENV N_CTX=4096

ENTRYPOINT ["/app/entrypoint.sh"]
