#!/bin/bash
# Start both STT and TTS sidecar services
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VOICE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${VOICE_DIR}/logs"
mkdir -p "$LOG_DIR"

echo "Starting lobs-voice services..."

# Check if services are already running
if curl -sf http://127.0.0.1:7423/health >/dev/null 2>&1; then
  echo "  STT already running on :7423"
else
  echo "  Starting STT (whisper.cpp) on :7423..."
  bash "${VOICE_DIR}/stt/start-stt.sh" > "${LOG_DIR}/stt.log" 2>&1 &
  echo "  STT PID: $!"
fi

if curl -sf http://127.0.0.1:7422/health >/dev/null 2>&1; then
  echo "  TTS already running on :7422"
else
  echo "  Starting TTS (Chatterbox) on :7422..."
  bash "${VOICE_DIR}/tts/start-tts.sh" > "${LOG_DIR}/tts.log" 2>&1 &
  echo "  TTS PID: $!"
fi

echo ""
echo "Waiting for services to be ready..."

# Wait for STT
for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:7423/health >/dev/null 2>&1; then
    echo "  ✓ STT ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "  ✗ STT failed to start (check logs/stt.log)"
  fi
  sleep 1
done

# Wait for TTS (model download may take a while on first run)
for i in $(seq 1 120); do
  if curl -sf http://127.0.0.1:7422/health >/dev/null 2>&1; then
    echo "  ✓ TTS ready"
    break
  fi
  if [ "$i" -eq 120 ]; then
    echo "  ✗ TTS failed to start (check logs/tts.log)"
  fi
  sleep 1
done

echo ""
echo "lobs-voice services started. Logs in: ${LOG_DIR}/"
