#!/bin/bash
# Wrapper script for launchd — reads tunnel config from macOS Keychain
# and execs autossh. Installed to ~/.local/bin/ by setup-tunnel.sh.

set -euo pipefail

SERVICE="llama-tunnel"

read_keychain() {
  security find-generic-password -s "$SERVICE" -a "$1" -w 2>/dev/null
}

SSH_HOST=$(read_keychain "ssh-host") || {
  echo "ERROR: Keychain entry '$SERVICE/ssh-host' not found. Run setup-tunnel.sh first." >&2
  exit 1
}

PORT_FORWARD=$(read_keychain "port-forward") || {
  echo "ERROR: Keychain entry '$SERVICE/port-forward' not found. Run setup-tunnel.sh first." >&2
  exit 1
}

AUTOSSH_PATH=$(read_keychain "autossh-path") || {
  echo "ERROR: Keychain entry '$SERVICE/autossh-path' not found. Run setup-tunnel.sh first." >&2
  exit 1
}

if [ ! -x "$AUTOSSH_PATH" ]; then
  echo "ERROR: autossh not found at '$AUTOSSH_PATH'" >&2
  exit 1
fi

exec "$AUTOSSH_PATH" \
  -M 0 \
  -N \
  -o ServerAliveInterval=60 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -L "$PORT_FORWARD" \
  "$SSH_HOST"
