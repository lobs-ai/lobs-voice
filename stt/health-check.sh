#!/bin/bash
##
## Check if the whisper.cpp STT server is healthy
##
## Usage: ./health-check.sh [port]
##
## Exit codes:
##   0 — healthy
##   1 — not responding
##

PORT="${1:-7423}"
URL="http://127.0.0.1:${PORT}/health"

if response=$(curl -sf --max-time 5 "$URL" 2>/dev/null); then
  echo "✓ STT service healthy (port ${PORT})"
  echo "  ${response}"
  exit 0
else
  echo "✗ STT service not responding on port ${PORT}"
  echo "  Tried: ${URL}"
  exit 1
fi
