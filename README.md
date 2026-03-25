# lobs-voice

Local STT + TTS sidecar services for Discord voice integration with [lobs-core](https://github.com/lobs-ai/lobs-core).

All inference runs locally on Apple Silicon (M4) — no API costs, no latency from network calls, fully offline.

## Architecture

```
Discord Voice ─── per-user Opus ──► STT (whisper.cpp) ──► Claude ──► TTS (Chatterbox) ──► Discord Playback
                                     port 7423              API        port 7422
                                     Core ML/ANE            stream     MPS/Metal
```

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full design.

## Quick Start

### Prerequisites

- macOS with Apple Silicon (M4/M3/M2/M1)
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3.11+ with pip
- CMake (`brew install cmake`)

### 1. Build & download STT

```bash
cd stt
make setup    # clones whisper.cpp + builds with Core ML
make model    # downloads base.en model (~142MB)
```

### 2. Install TTS

```bash
cd tts
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 3. Start both services

```bash
./scripts/start-all.sh
```

### 4. Verify

```bash
./scripts/health-check.sh
# STT: {"status":"ok","model":"base.en"}
# TTS: {"status":"ok","model":"chatterbox","device":"mps"}
```

### 5. Configure lobs-core

Create `~/.lobs/config/voice.json`:

```json
{
  "enabled": true,
  "stt": { "url": "http://localhost:7423" },
  "tts": { "url": "http://localhost:7422" }
}
```

Then use `/join` in Discord to connect Lobs to a voice channel.

## Model Swapping

### STT Models

| Model | Size | Speed (3s audio) | Accuracy |
|-------|------|-------------------|----------|
| tiny.en | 75 MB | ~0.1s | 97% |
| base.en | 142 MB | ~0.3s | 99% |
| small.en | 466 MB | ~0.8s | 99.5% |
| large-v3-turbo | 1.5 GB | ~2s | 99.8% |

```bash
cd stt/models
./download-model.sh small.en
# Then restart with:
./start-stt.sh --model models/ggml-small.en.bin
```

### TTS Voices

Upload a 5-15 second WAV sample for zero-shot voice cloning:

```bash
curl -X POST http://localhost:7422/v1/voices \
  -F "file=@sample.wav" \
  -F "name=custom-voice"
```

Then set in config: `"voice": "custom-voice"`

## Services

| Service | Port | Description |
|---------|------|-------------|
| lobs-voice-stt | 7423 | whisper.cpp with Core ML — OpenAI-compatible transcription API |
| lobs-voice-tts | 7422 | Chatterbox TTS with MPS — OpenAI-compatible speech API |

Both bind to `127.0.0.1` only (localhost).

## Discord Commands

| Command | Description |
|---------|-------------|
| `/join [channel]` | Join a voice channel |
| `/leave` | Leave voice channel |
| `/voice mode <keyword\|always>` | Set trigger mode |
| `/voice status` | Show voice session info |

In **keyword mode** (default), say "Lobs" or "Hey Lobs" to trigger a response.
In **always mode**, every utterance is sent to Claude.

## Development

```bash
# Check service health
./scripts/health-check.sh

# View logs
# STT and TTS log to stdout — use the start scripts directly for development

# Test STT
curl -X POST http://localhost:7423/v1/audio/transcriptions \
  -F "file=@test.wav" \
  -F "model=base.en"

# Test TTS
curl -X POST http://localhost:7422/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model":"chatterbox","input":"Hello world","voice":"default"}' \
  --output test-output.wav
```

## License

Private — part of the lobs AI agent platform.
