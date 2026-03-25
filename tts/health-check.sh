#!/bin/bash
# Quick health check for the TTS service
# Usage: ./health-check.sh [port]

PORT=${1:-7422}

response=$(curl -sf "http://127.0.0.1:${PORT}/health" 2>&1)
if [ $? -eq 0 ]; then
  echo "✅ TTS service healthy on port ${PORT}"
  echo "   ${response}" | python3 -m json.tool 2>/dev/null || echo "   ${response}"
else
  echo "❌ TTS service not responding on port ${PORT}"
  exit 1
fi
