#!/bin/bash
# Start the Chatterbox TTS server
# Usage: ./start-tts.sh [--port 7422] [--host 127.0.0.1]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=7422
HOST=127.0.0.1

while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    *) shift ;;
  esac
done

mkdir -p "${SCRIPT_DIR}/voices"

echo "═══════════════════════════════════════════════"
echo "  lobs-voice-tts — Chatterbox TTS Server"
echo "  Host: ${HOST}:${PORT}"
echo "  Voices dir: ${SCRIPT_DIR}/voices"
echo "═══════════════════════════════════════════════"

cd "$SCRIPT_DIR"
exec python server.py --host "$HOST" --port "$PORT"
