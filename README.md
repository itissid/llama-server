# llama-server

llama-cpp-python server running on a GPU host (TrueNAS RTX 3090), serving Qwen2.5-7B-Instruct via an OpenAI-compatible API. Designed as a local LLM backend for [Handy](https://github.com/cjpais/handy) STT post-processing.

## Server (GPU host)

```bash
# Build and start the container
./run-llama.sh

# Stop the container
./stop-llama.sh
```

The container auto-downloads the model on first start to `/mnt/AIPool/models/`. Runs on port 8100 with `--gpus all`.

## Mac-side SSH Tunnel

The tunnel scripts use macOS Keychain to store connection config, so no secrets are committed to the repo.

### First-time setup

```bash
# Requires autossh — install if needed:
brew install autossh

# Run setup (pops macOS dialogs to collect SSH host and port config):
./setup-tunnel.sh
```

The setup script will:
1. Prompt for your SSH host name (from `~/.ssh/config`)
2. Prompt for the port forwarding spec (`LOCAL_PORT:REMOTE_HOST:REMOTE_PORT`)
3. Auto-detect the autossh binary path
4. Store all values in macOS Keychain (service: `llama-tunnel`)
5. Install the launchd service (starts on login, auto-reconnects)

### Verify

```bash
launchctl list | grep llama-tunnel
curl http://localhost:8100/v1/models
```

### Uninstall

```bash
./uninstall-tunnel.sh
```

Removes the launchd service, Keychain entries, and installed wrapper script.

### Logs

```bash
tail -f /tmp/llama-tunnel.err
tail -f /tmp/llama-tunnel.out
```

### SSH key passphrase

If your SSH key has a passphrase, add these to the relevant host entry in `~/.ssh/config` so launchd can retrieve it without a terminal:

```
AddKeysToAgent yes
UseKeychain yes
```

Then run: `ssh-add --apple-use-keychain ~/.ssh/your_key`
