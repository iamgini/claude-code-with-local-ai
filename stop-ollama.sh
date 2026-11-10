#!/usr/bin/env bash
# Unload all running models from GPU memory and stop the Ollama service.

PLIST="$HOME/Library/LaunchAgents/sh.brew.ollama.plist"

# Unload any running models first
RUNNING=$(ollama ps 2>/dev/null | tail -n +2 | awk '{print $1}')
if [ -n "$RUNNING" ]; then
  echo "Stopping models:"
  while IFS= read -r model; do
    echo "  - $model"
    ollama stop "$model" 2>/dev/null
  done <<< "$RUNNING"
else
  echo "No models currently loaded."
fi

# Stop the service
echo "Stopping Ollama service..."
launchctl unload "$PLIST" 2>/dev/null && echo "Ollama stopped." || echo "Ollama was not running."
