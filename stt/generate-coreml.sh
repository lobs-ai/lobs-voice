#!/bin/bash
##
## Generate a Core ML encoder model for Apple Neural Engine acceleration
##
## Usage: ./generate-coreml.sh [model_name]
##
## Examples:
##   ./generate-coreml.sh base.en    (default)
##   ./generate-coreml.sh small.en
##
## Prerequisites:
##   pip install ane_transformers openai-whisper coremltools
##
## This generates a .mlmodelc directory alongside the GGML model in
## whisper.cpp/models/. whisper-server auto-detects and uses it.
##
## Note: Generation can take several minutes depending on model size.
##

set -euo pipefail

MODEL="${1:-base.en}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHISPER_DIR="${SCRIPT_DIR}/whisper.cpp"
GENERATE_SCRIPT="${WHISPER_DIR}/models/generate-coreml-model.sh"

# Check whisper.cpp is cloned
if [ ! -d "$WHISPER_DIR" ]; then
  echo "Error: whisper.cpp not found at ${WHISPER_DIR}"
  echo "Run 'make clone' from the stt/ directory first."
  exit 1
fi

if [ ! -f "$GENERATE_SCRIPT" ]; then
  echo "Error: Core ML generation script not found."
  echo "Your whisper.cpp clone may be incomplete."
  exit 1
fi

# Check Python dependencies
for pkg in ane_transformers coremltools openai-whisper; do
  # openai-whisper installs as "whisper" in python
  check_pkg="$pkg"
  if [ "$pkg" = "openai-whisper" ]; then
    check_pkg="whisper"
  fi
  if ! python3 -c "import $check_pkg" 2>/dev/null; then
    echo "Error: Missing Python package: ${pkg}"
    echo ""
    echo "Install prerequisites:"
    echo "  pip install ane_transformers openai-whisper coremltools"
    exit 1
  fi
done

# Check if already generated
COREML_DIR="${WHISPER_DIR}/models/ggml-${MODEL}-encoder.mlmodelc"
if [ -d "$COREML_DIR" ]; then
  echo "Core ML model already exists: ggml-${MODEL}-encoder.mlmodelc"
  echo "Delete it first to regenerate."
  exit 0
fi

echo "═══ Generating Core ML model for: ${MODEL} ═══"
echo "This may take several minutes..."
echo ""

cd "${WHISPER_DIR}"
bash models/generate-coreml-model.sh "$MODEL"

if [ -d "$COREML_DIR" ]; then
  echo ""
  echo "✓ Core ML model generated: ggml-${MODEL}-encoder.mlmodelc"
  echo "  whisper-server will auto-detect and use it for ANE acceleration."
else
  echo ""
  echo "✗ Core ML generation may have failed."
  echo "  Expected: ${COREML_DIR}"
  exit 1
fi
