#!/bin/bash
# Stop both STT and TTS sidecar services
set -e

echo "Stopping lobs-voice services..."

# Kill whisper-server
if pgrep -f "whisper-server.*7423" >/dev/null 2>&1; then
  pkill -f "whisper-server.*7423" || true
  echo "  ✓ STT stopped"
else
  echo "  - STT not running"
fi

# Kill TTS server
if pgrep -f "server.py.*7422" >/dev/null 2>&1; then
  pkill -f "server.py.*7422" || true
  echo "  ✓ TTS stopped"
else
  echo "  - TTS not running"
fi

echo "Done."
