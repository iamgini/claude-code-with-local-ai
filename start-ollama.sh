#!/usr/bin/env bash
# Start Ollama as a background service and wait until it is ready.
# Uses launchctl directly to preserve custom plist settings (context length, etc.)

PLIST="$HOME/Library/LaunchAgents/sh.brew.ollama.plist"
OLLAMA_URL="http://localhost:11434"

if ! [ -f "$PLIST" ]; then
  echo "ERROR: Ollama plist not found at $PLIST"
  echo "Run 'brew install ollama' and 'brew services start ollama' first."
  exit 1
fi

# Check if already running
if curl -sf "$OLLAMA_URL" > /dev/null 2>&1; then
  echo "Ollama is already running."
  ollama list
  exit 0
fi

echo "Starting Ollama..."
launchctl load "$PLIST"

# Wait until ready
printf "Waiting for Ollama"
for i in $(seq 1 15); do
  if curl -sf "$OLLAMA_URL" > /dev/null 2>&1; then
    echo " ready."
    break
  fi
  printf "."
  sleep 1
done

if ! curl -sf "$OLLAMA_URL" > /dev/null 2>&1; then
  echo " timed out. Check logs: tail /opt/homebrew/var/log/ollama.log"
  exit 1
fi

echo "Models available:"
ollama list
