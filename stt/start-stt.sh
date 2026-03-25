#!/bin/bash
##
## Start the whisper.cpp HTTP transcription server
##
## Usage: ./start-stt.sh [options]
##
## Options:
##   --model PATH   Path to GGML model (default: whisper.cpp/models/ggml-base.en.bin
##                  or models/ggml-base.en.bin if in models/ dir)
##   --port PORT    Port to listen on (default: 7423)
##   --help         Show this help
##
## API:
##   POST /v1/audio/transcriptions   OpenAI-compatible transcription
##   GET  /health                     Health check
##
## Examples:
##   ./start-stt.sh
##   ./start-stt.sh --model models/ggml-small.en.bin --port 8080
##   ./start-stt.sh --model whisper.cpp/models/ggml-large-v3-turbo.bin
##

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=7423

# Default model: check models/ dir first, then whisper.cpp/models/
if [ -f "${SCRIPT_DIR}/models/ggml-base.en.bin" ]; then
  MODEL="${SCRIPT_DIR}/models/ggml-base.en.bin"
else
  MODEL="${SCRIPT_DIR}/whisper.cpp/models/ggml-base.en.bin"
fi

SERVER_BIN="${SCRIPT_DIR}/whisper.cpp/build/bin/whisper-server"

# ─── Parse arguments ────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case $1 in
    --model)
      MODEL="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --help|-h)
      grep '^##' "$0" | sed 's/^## \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage."
      exit 1
      ;;
  esac
done

# ─── Validate ────────────────────────────────────────────────────────────

if [ ! -f "$SERVER_BIN" ]; then
  echo "Error: whisper-server binary not found at:"
  echo "  ${SERVER_BIN}"
  echo ""
  echo "Build it first:"
  echo "  cd stt && make"
  exit 1
fi

if [ ! -f "$MODEL" ]; then
  echo "Error: Model not found at:"
  echo "  ${MODEL}"
  echo ""
  echo "Download a model first:"
  echo "  cd stt/models && ./download-model.sh base.en"
  exit 1
fi

# Check if port is already in use
if lsof -i ":${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Warning: Port ${PORT} is already in use."
  echo ""
  lsof -i ":${PORT}" -sTCP:LISTEN
  echo ""
  echo "Stop the existing process or use --port to pick a different port."
  exit 1
fi

# ─── Start ───────────────────────────────────────────────────────────────

MODEL_NAME=$(basename "$MODEL" .bin | sed 's/^ggml-//')
MODEL_SIZE=$(du -h "$MODEL" | cut -f1)

echo "═══ lobs-voice STT ═══"
echo "  Model:  ${MODEL_NAME} (${MODEL_SIZE})"
echo "  Port:   ${PORT}"
echo "  API:    http://127.0.0.1:${PORT}/v1/audio/transcriptions"
echo "  Health: http://127.0.0.1:${PORT}/health"
echo ""

exec "$SERVER_BIN" \
  --model "$MODEL" \
  --host 127.0.0.1 \
  --port "$PORT" \
  --inference-path "/v1/audio/transcriptions" \
  --convert \
  --print-progress
