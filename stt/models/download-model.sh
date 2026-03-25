#!/bin/bash
##
## Download a whisper.cpp GGML model from Hugging Face
##
## Usage: ./download-model.sh [model_name]
##
## Examples:
##   ./download-model.sh base.en        (default — 142MB, great balance)
##   ./download-model.sh tiny.en        (75MB, fastest)
##   ./download-model.sh small.en       (466MB, highest accuracy)
##   ./download-model.sh large-v3-turbo (1.5GB, best quality)
##
## Available models:
##   tiny.en, tiny, base.en, base, small.en, small,
##   medium.en, medium, large-v1, large-v2, large-v3,
##   large-v3-turbo
##

set -euo pipefail

MODEL="${1:-base.en}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHISPER_DIR="${SCRIPT_DIR}/../whisper.cpp"
DOWNLOAD_SCRIPT="${WHISPER_DIR}/models/download-ggml-model.sh"
DEST_FILE="${SCRIPT_DIR}/ggml-${MODEL}.bin"

# Check whisper.cpp is cloned
if [ ! -f "$DOWNLOAD_SCRIPT" ]; then
  echo "Error: whisper.cpp not found at ${WHISPER_DIR}"
  echo "Run 'make clone' from the stt/ directory first."
  exit 1
fi

# Skip if already downloaded
if [ -f "$DEST_FILE" ]; then
  SIZE=$(du -h "$DEST_FILE" | cut -f1)
  echo "Model already exists: ggml-${MODEL}.bin (${SIZE})"
  echo "Delete it first to re-download."
  exit 0
fi

echo "═══ Downloading model: ${MODEL} ═══"

# Run the upstream download script (downloads into whisper.cpp/models/)
cd "${WHISPER_DIR}/models"
bash download-ggml-model.sh "$MODEL"

# Move to our models/ directory for cleaner organization
UPSTREAM_FILE="${WHISPER_DIR}/models/ggml-${MODEL}.bin"
if [ -f "$UPSTREAM_FILE" ]; then
  mv "$UPSTREAM_FILE" "$DEST_FILE"
  SIZE=$(du -h "$DEST_FILE" | cut -f1)
  echo "✓ Downloaded: models/ggml-${MODEL}.bin (${SIZE})"
else
  echo "✗ Download failed — expected file not found: ${UPSTREAM_FILE}"
  exit 1
fi
