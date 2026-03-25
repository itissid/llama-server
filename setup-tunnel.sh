#!/bin/bash
# One-time setup for the llama-server autossh tunnel on macOS.
# Prompts for config via native dialogs, stores in Keychain,
# installs the launchd service.

set -euo pipefail

SERVICE="llama-tunnel"
LABEL="local.llama-tunnel"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
WRAPPER_DEST="$HOME/.local/bin/launch-llama-tunnel.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Helper: macOS dialog prompt ---
prompt_dialog() {
  local message="$1"
  local default="$2"
  osascript -e "
    set result to display dialog \"$message\" default answer \"$default\" ¬
      with title \"llama-tunnel setup\" ¬
      buttons {\"Cancel\", \"OK\"} default button \"OK\"
    return text returned of result
  " 2>/dev/null
}

# --- Helper: store in Keychain (update if exists) ---
store_keychain() {
  local account="$1"
  local value="$2"
  # Delete existing entry if present
  security delete-generic-password -s "$SERVICE" -a "$account" 2>/dev/null || true
  security add-generic-password -s "$SERVICE" -a "$account" -w "$value"
}

# --- Check for existing installation ---
if launchctl list | grep -q "$LABEL"; then
  echo "Existing tunnel service found. Unloading..."
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# --- Collect config via dialogs ---
echo "Opening setup dialogs..."

SSH_HOST=$(prompt_dialog "SSH host name from ~/.ssh/config (e.g. my-server, bastion-host):" "")
if [ -z "$SSH_HOST" ]; then
  echo "Setup cancelled." >&2
  exit 1
fi

PORT_FORWARD=$(prompt_dialog "Port forwarding spec as LOCAL_PORT:REMOTE_HOST:REMOTE_PORT (e.g. 8080:127.0.0.1:8080):" "")
if [ -z "$PORT_FORWARD" ]; then
  echo "Setup cancelled." >&2
  exit 1
fi

# Auto-detect autossh
AUTOSSH_DEFAULT=$(which autossh 2>/dev/null || echo "/opt/homebrew/bin/autossh")
AUTOSSH_PATH=$(prompt_dialog "Path to autossh binary. Install with 'brew install autossh' if not present. (Apple Silicon: /opt/homebrew/bin/autossh, Intel: /usr/local/bin/autossh):" "$AUTOSSH_DEFAULT")
if [ ! -x "$AUTOSSH_PATH" ]; then
  echo "ERROR: autossh not found at '$AUTOSSH_PATH'. Install with: brew install autossh" >&2
  exit 1
fi

# --- Store in Keychain ---
echo "Storing config in Keychain (service: $SERVICE)..."
store_keychain "ssh-host" "$SSH_HOST"
store_keychain "port-forward" "$PORT_FORWARD"
store_keychain "autossh-path" "$AUTOSSH_PATH"

# --- Install wrapper script ---
mkdir -p "$(dirname "$WRAPPER_DEST")"
cp "$SCRIPT_DIR/launch-tunnel.sh" "$WRAPPER_DEST"
chmod +x "$WRAPPER_DEST"
echo "Installed wrapper to $WRAPPER_DEST"

# --- Write plist ---
cat > "$PLIST_DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$WRAPPER_DEST</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>/tmp/llama-tunnel.err</string>
  <key>StandardOutPath</key>
  <string>/tmp/llama-tunnel.out</string>
</dict>
</plist>
PLIST
echo "Wrote plist to $PLIST_DEST"

# --- Load service ---
launchctl load "$PLIST_DEST"
echo ""
echo "Setup complete!"
echo "  SSH host:     $SSH_HOST"
echo "  Port forward: $PORT_FORWARD"
echo "  autossh:      $AUTOSSH_PATH"
echo ""
echo "Verify with:"
LOCAL_PORT="${PORT_FORWARD%%:*}"
echo "  launchctl list | grep $LABEL"
echo "  curl http://localhost:$LOCAL_PORT/v1/models"
