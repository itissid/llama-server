#!/bin/bash
CONTAINER_NAME="llama-server"

if sudo docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping $CONTAINER_NAME..."
    sudo docker stop "$CONTAINER_NAME"
    sudo docker rm "$CONTAINER_NAME"
    echo "llama-server stopped"
else
    echo "Container $CONTAINER_NAME is not running"
fi
