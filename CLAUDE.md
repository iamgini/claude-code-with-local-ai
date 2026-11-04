# claude-code-with-local-ai

Privacy-first Claude Code setup — all LLM inference stays on your machine.

## Purpose

This repo documents how to run Claude Code against a local Ollama instance
so that your source code, prompts, and context never leave your machine.

## Stack

- Claude Code CLI (Anthropic) — the coding agent
- Ollama (native, not containerized) — local inference server
- Local model (Qwen, Devstral, Gemma, etc.) — LLM running on-device

## Key principle

No code or file content is sent to Anthropic when `ANTHROPIC_BASE_URL`
points to localhost. Telemetry is also disabled via
`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`.

## Git conventions

- No `Co-Authored-By` trailers for Claude or any AI assistant.
