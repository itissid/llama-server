#!/bin/bash
# Uninstall the llama-server autossh tunnel service.
# Stops the service, removes Keychain entries, and cleans up installed files.

set -euo pipefail

SERVICE="llama-tunnel"
LABEL="local.llama-tunnel"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
WRAPPER="$HOME/.local/bin/launch-llama-tunnel.sh"

# --- Unload service ---
if launchctl list | grep -q "$LABEL"; then
  echo "Unloading $LABEL..."
  launchctl unload "$PLIST" 2>/dev/null || true
  # Also remove registration in case unload leaves it lingering
  launchctl remove "$LABEL" 2>/dev/null || true
else
  echo "Service not loaded."
fi

# --- Remove plist ---
if [ -f "$PLIST" ]; then
  rm "$PLIST"
  echo "Removed $PLIST"
fi

# --- Remove wrapper ---
if [ -f "$WRAPPER" ]; then
  rm "$WRAPPER"
  echo "Removed $WRAPPER"
fi

# --- Delete Keychain entries ---
for account in ssh-host port-forward autossh-path; do
  if security find-generic-password -s "$SERVICE" -a "$account" >/dev/null 2>&1; then
    security delete-generic-password -s "$SERVICE" -a "$account" >/dev/null 2>&1
    echo "Deleted Keychain entry: $SERVICE/$account"
  fi
done

echo ""
echo "Uninstall complete."
