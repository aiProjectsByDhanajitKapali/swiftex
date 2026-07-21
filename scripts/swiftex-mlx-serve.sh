#!/usr/bin/env bash
# Start the local MLX (vllm-mlx) server that Swiftex's "MLX" backend talks to.
#
# Backend toggle in Swiftex Panel expects an OpenAI-compatible API at:
#   base URL: http://127.0.0.1:<PORT>/v1
#   model:    $MODEL (below)
#
# vllm-mlx lives in a Python 3.11 venv (the wheels need 3.11+); 3.9 fails to install.
set -euo pipefail

VENV="${SWIFTEX_MLX_VENV:-$HOME/.swiftex-mlx/venv}"
MODEL="${SWIFTEX_MLX_MODEL:-mlx-community/Qwen2.5-Coder-14B-Instruct-4bit}"
PORT="${SWIFTEX_MLX_PORT:-8000}"

BIN="$VENV/bin/vllm-mlx"
if [[ ! -x "$BIN" ]]; then
  echo "vllm-mlx not found at $BIN" >&2
  echo "Install it once with:" >&2
  echo "  python3.11 -m venv \"$VENV\" && \"$VENV/bin/pip\" install --upgrade pip vllm-mlx" >&2
  exit 1
fi

# Already serving? Don't double-launch.
if curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/v1/models" 2>/dev/null | grep -q 200; then
  echo "MLX server already up on :$PORT"
  curl -s "http://127.0.0.1:$PORT/v1/models"; echo
  exit 0
fi

echo "Starting vllm-mlx: $MODEL on :$PORT (first run downloads the model)…"
exec "$BIN" serve "$MODEL" --port "$PORT" --continuous-batching
