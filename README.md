# Claude Code with Local AI

Run Claude Code entirely on your machine — no code, no prompts, no file contents sent to Anthropic or any cloud.

## Why

By default, Claude Code sends everything — your files, prompts, context — to Anthropic's API. If you work with client code, NDAs, proprietary projects, or just prefer privacy, this setup redirects all inference to a local model running via Ollama.

## How it works

```
Your files
    │
    ▼
Claude Code ──► localhost:11434 ──► Ollama ──► model on disk
```

One env var (`ANTHROPIC_BASE_URL`) is all it takes to redirect Claude Code away from the cloud. Combined with disabling telemetry, nothing leaves your machine.

## Prerequisites

- macOS Apple Silicon (M1/M2/M3/M4/M5) — or Linux with NVIDIA GPU
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- [Ollama](https://ollama.com) installed natively (not in a container — see [Why not containerized?](#why-not-containerized))

## Setup

### 1. Install Ollama (native)

```bash
brew install ollama
brew services start ollama   # run as background service, auto-starts on login
```

### 2. Set context length

Claude Code's system prompt alone exceeds Ollama's default 4K context window. Set a higher context via launchd (so it persists across reboots):

```bash
# Edit the service plist
nano ~/Library/LaunchAgents/sh.brew.ollama.plist
```

Add `OLLAMA_CONTEXT_LENGTH` to the `EnvironmentVariables` dict:

```xml
<key>OLLAMA_CONTEXT_LENGTH</key>
<string>32768</string>
```

Then reload:
```bash
launchctl unload ~/Library/LaunchAgents/sh.brew.ollama.plist
launchctl load  ~/Library/LaunchAgents/sh.brew.ollama.plist
```

> **Why 32K and not higher?** Claude Code's system prompt is ~21K tokens. 32K fits it comfortably and keeps the KV cache small enough to run entirely on the Apple Silicon GPU. Setting it higher (e.g. 131K) overflows GPU memory and causes partial CPU offload — significantly slower.

### 3. Pull a model

Choose based on your unified memory:

| RAM    | Recommended model       | Size   | Notes                               |
|--------|-------------------------|--------|-------------------------------------|
| 8 GB   | `qwen2.5-coder:7b`      | ~4 GB  | Minimal, simple tasks only          |
| 16 GB  | `qwen2.5-coder:14b`     | ~9 GB  | Good balance of speed/quality       |
| 24 GB  | `devstral:24b`          | ~14 GB | Best tool-call support at this tier |
| 32 GB+ | `qwen2.5-coder:32b`     | ~20 GB | Near-cloud quality                  |
| 48 GB+ | `devstral:24b`          | ~14 GB | Fits fully in GPU, fast             |

```bash
ollama pull devstral:24b          # best for agentic coding (tool-call trained)
ollama pull qwen2.5-coder:14b    # lighter alternative for quick tasks
```

> **Important:** Choose a model trained for tool use / function calling. Claude Code's agentic loop is tool-call heavy. Models like `devstral` and `qwen2.5-coder` work well. Avoid older completion-tuned models.

### 4. Configure Claude Code

Add to `~/.zshrc` or `~/.bashrc`:

```bash
claude-local() {
  env -u CLAUDE_CODE_USE_VERTEX \
      -u ANTHROPIC_VERTEX_PROJECT_ID \
      -u CLOUD_ML_REGION \
      -u ANTHROPIC_API_KEY \
      ANTHROPIC_BASE_URL="http://localhost:11434" \
      ANTHROPIC_AUTH_TOKEN="ollama" \
      ANTHROPIC_MODEL="${CLAUDE_LOCAL_MODEL:-devstral:24b}" \
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
      claude "$@"
}
```

The `env -u` lines unset any cloud provider variables (Vertex AI, etc.) that may be active in your shell. Remove those lines if you don't use Vertex AI or Bedrock.

Reload your shell:
```bash
source ~/.zshrc
```

Override the model on the fly:
```bash
CLAUDE_LOCAL_MODEL=qwen2.5-coder:14b claude-local
```

### 5. Verify

```bash
# Confirm Ollama is running
curl http://localhost:11434/api/tags

# Start Claude Code against local Ollama
claude-local
```

Watch Ollama logs during a session to confirm all requests hit localhost:
```bash
tail -f /opt/homebrew/var/log/ollama.log
```

You should see `POST /v1/messages` hitting `127.0.0.1` — nothing going to `anthropic.com`.

## Common pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| First response takes 2–3 minutes | Claude Code's ~21K token system prompt processed on first turn | Expected — subsequent turns use KV cache and are much faster |
| Claude Code hangs or empty responses | Context too small for system prompt | Set `OLLAMA_CONTEXT_LENGTH=32768` |
| Slow even after first turn | Context too large → GPU overflow → partial CPU offload | Reduce context to 32768 |
| Tool calls don't execute, agentic loop breaks | Model not trained for tool use | Switch to `devstral` or `qwen2.5-coder` |
| Claude Code still contacts Anthropic | Missing telemetry flag | Add `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` |
| Auth conflict warning | Cloud credentials still active | Use `env -u` to unset provider vars in the shell function |
| `--bare` flag recommended in some guides | Strips system prompt → faster but disables CLAUDE.md, hooks, auto-memory | Avoid unless necessary |

## KV cache

Ollama ships with KV cache enabled by default. The brew formula also sets:

```
OLLAMA_FLASH_ATTENTION=1       # faster attention computation
OLLAMA_KV_CACHE_TYPE=q8_0     # 8-bit quantized KV cache (halves memory vs fp16)
```

On first turn: system prompt (~21K tokens) is processed and cached. On subsequent turns: only new tokens are processed — significantly faster.

The model stays in GPU memory for 5 minutes of inactivity (`OLLAMA_KEEP_ALIVE=5m`). After that it unloads and the next request triggers a cold start.

## Why not containerized?

On macOS, containers cannot access the Apple Silicon GPU (Metal). Running Ollama inside Podman or Docker means CPU-only inference — 3–5x slower, often unusably slow for interactive coding.

**Run Ollama natively on Mac.** Use containers for other services (databases, ChromaDB, etc.) but not for the LLM inference server.

On Linux with NVIDIA GPUs, containerized Ollama works fine with GPU passthrough:

```bash
podman run -d --name ollama \
  --device nvidia.com/gpu=all \
  -p 11434:11434 \
  -v ollama-models:/root/.ollama \
  ollama/ollama

podman exec ollama ollama pull devstral:24b
```

## Limitations

- **No internet access** — the local model cannot browse the web or call external APIs. Claude Code's web search tool only works when connected to Anthropic's cloud.
- **First response latency** — always slow (~2–3 min) due to system prompt processing; unavoidable with local models.
- **Model quality** — local models are capable for everyday coding but trail cloud models on complex multi-step reasoning.
- **Context window** — capped at what fits in your GPU memory. At 32K context on a 48 GB machine, the model + KV cache fits in ~23 GB.
