#!/bin/bash
# Health check for both lobs-voice services

echo "lobs-voice health check"
echo "======================="

# STT
printf "STT (port 7423): "
if response=$(curl -sf http://127.0.0.1:7423/health 2>/dev/null); then
  echo "✓ $response"
else
  echo "✗ not responding"
fi

# TTS
printf "TTS (port 7422): "
if response=$(curl -sf http://127.0.0.1:7422/health 2>/dev/null); then
  echo "✓ $response"
else
  echo "✗ not responding"
fi
