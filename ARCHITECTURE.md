# lobs-voice — Architecture

**Purpose:** Local STT + TTS sidecar services for Discord voice integration with lobs-core.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Discord Voice Channel                        │
│  ┌──────────────┐                           ┌──────────────────┐    │
│  │ Per-user Opus │ ──► receive               │ AudioPlayer      │    │
│  │ audio streams │                           │ (playback)       │◄── │
│  └──────────────┘                           └──────────────────┘    │
└────────┬────────────────────────────────────────────▲────────────────┘
         │ decode Opus → PCM                          │ Opus-encoded WAV
         │ VAD + buffer (~2s chunks)                  │
         ▼                                            │
┌─────────────────────┐                    ┌─────────────────────┐
│   whisper.cpp        │                    │   Chatterbox TTS    │
│   (lobs-voice-stt)   │                    │   (lobs-voice-tts)  │
│                      │                    │                     │
│   POST /v1/audio/    │                    │   POST /v1/audio/   │
│     transcriptions   │                    │     speech          │
│                      │                    │                     │
│   Port 7423          │                    │   Port 7422         │
│   Core ML + Metal    │                    │   MPS (Metal)       │
│   Model: base.en     │                    │   Model: Chatterbox │
│   (swappable)        │                    │   Turbo             │
└─────────┬────────────┘                    └──────────▲──────────┘
          │ text                                       │ text (sentences)
          ▼                                            │
┌──────────────────────────────────────────────────────┴──────────────┐
│                         lobs-core                                    │
│                                                                      │
│  src/services/voice/                                                 │
│  ├── manager.ts        Voice session lifecycle                       │
│  ├── receiver.ts       Per-user audio receive + STT pipeline         │
│  ├── speaker.ts        Claude → TTS → playback pipeline              │
│  ├── vad.ts            Voice activity detection (silence trimming)   │
│  ├── transcript.ts     Conversation transcript + context             │
│  └── types.ts          Shared types                                  │
│                                                                      │
│  Discord commands: /join, /leave, /voice                             │
└──────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. STT Service — `lobs-voice-stt` (Port 7423)

**Stack:** whisper.cpp compiled with Core ML support for Apple Neural Engine acceleration.

**API:** OpenAI-compatible transcription endpoint.

```
POST /v1/audio/transcriptions
Content-Type: multipart/form-data

file: <audio.wav>         (16kHz mono PCM16)
model: base.en            (ignored by server, uses loaded model)
language: en              (optional)
response_format: json     (default)

Response: { "text": "Hello world" }
```

```
GET /health
Response: { "status": "ok", "model": "base.en", "device": "coreml" }
```

**Model swapping:** The server loads one model at startup via `--model` flag. To swap models:
- Stop the server
- Start with a different `--model` path
- Models live in `models/` directory with naming convention `ggml-{name}.bin`
- Available: tiny.en, base.en, small.en, medium.en, large-v3-turbo
- Core ML variants: `models/ggml-{name}-encoder.mlmodelc/` (auto-detected)

**Performance targets (M4, base.en + Core ML):**
- 3s audio clip → ~0.2-0.4s transcription
- Memory: ~400MB resident
- Accuracy: 99-100% on clear speech

### 2. TTS Service — `lobs-voice-tts` (Port 7422)

**Stack:** Python FastAPI wrapping Chatterbox TTS with MPS (Metal) acceleration.

**API:** OpenAI-compatible speech endpoint.

```
POST /v1/audio/speech
Content-Type: application/json

{
  "model": "chatterbox",
  "input": "Hello, how are you?",
  "voice": "default",           // or path to reference audio for cloning
  "response_format": "wav",     // wav or pcm
  "speed": 1.0
}

Response: audio/wav binary stream
```

```
GET /health
Response: { "status": "ok", "model": "chatterbox", "device": "mps" }
```

```
POST /v1/voices
Content-Type: multipart/form-data
file: <reference.wav>       (5-15s of reference speech)
name: "rafe"

Response: { "id": "rafe", "path": "voices/rafe.wav" }
```

**Voice management:**
- Default voice ships with the model
- Custom voices: upload 5-15s reference WAV via `/v1/voices`
- Voices stored in `voices/` directory
- Voice cloning is zero-shot — just needs a reference clip

**Performance targets (M4 MPS, Chatterbox Turbo):**
- "Hello, how are you?" → ~0.3-0.5s generation
- Streams WAV as it generates (chunked transfer encoding)
- Memory: ~1-2GB resident

### 3. Voice Module in lobs-core — `src/services/voice/`

The Node.js orchestration layer that ties Discord ↔ STT ↔ Claude ↔ TTS together.

#### Files

**`manager.ts`** — Session lifecycle
- Join/leave voice channels via `@discordjs/voice`
- Track active sessions per guild
- Handle disconnects, channel moves, reconnection
- Expose `joinChannel(guildId, channelId)` and `leaveChannel(guildId)`

**`receiver.ts`** — Inbound audio pipeline
- Subscribe to per-user audio streams from `VoiceConnection.receiver`
- Decode Opus → PCM using `@discordjs/opus`
- Run VAD to detect speech boundaries
- Buffer speech segments (~1-3s)
- Send completed segments to whisper.cpp STT
- Emit transcription events with user identity

**`speaker.ts`** — Outbound audio pipeline
- Accept text input (from Claude streaming response)
- Buffer until sentence boundary (`.` `!` `?` or `\n`)
- Send each sentence to Chatterbox TTS
- Queue audio resources for Discord playback
- Pipeline parallelism: generate sentence N+1 while playing sentence N

**`vad.ts`** — Voice Activity Detection
- Simple energy-based VAD (RMS threshold)
- Configurable silence duration to mark end of utterance (default: 800ms)
- Prevents sending silence/noise to STT

**`transcript.ts`** — Conversation state
- Maintain rolling transcript of the voice conversation
- Track who said what (user ID → display name mapping)
- Provide context window for Claude prompts
- Configurable max context length (default: last 20 exchanges)

**`types.ts`** — Shared interfaces

#### Trigger Mechanism

How Claude gets invoked in a voice call:

1. **Keyword trigger (default):** Say "Lobs" or "Hey Lobs" → next utterance is sent to Claude
2. **Always-on mode:** Every utterance goes to Claude (togglable via `/voice mode`)
3. **Text command:** `/voice ask <question>` sends text directly to Claude in voice context

#### Discord Commands

```
/join [channel]     Join a voice channel (defaults to user's current channel)
/leave              Leave the voice channel
/voice mode <keyword|always>    Set trigger mode
/voice status       Show voice session info
```

## Latency Budget

| Stage | Target | Notes |
|-------|--------|-------|
| Audio buffer + VAD | ~1.5s | Collect speech until silence |
| Opus → PCM decode | <10ms | Native via @discordjs/opus |
| HTTP to whisper.cpp | <50ms | Localhost, ~16KB payload |
| whisper.cpp inference | ~300ms | base.en + Core ML on M4 |
| Claude first sentence | ~500-1000ms | Streaming, depends on model |
| Chatterbox TTS | ~300-500ms | Per sentence, MPS |
| Discord playback start | ~100ms | AudioPlayer queue |
| **Total to first audio** | **~2.5-3.5s** | From end of user speech |

This is comparable to natural conversation turn-taking pace.

## Configuration

```jsonc
// ~/.lobs/config/voice.json
{
  "enabled": true,
  "stt": {
    "url": "http://localhost:7423",
    "model": "base.en",       // for display/logging only — model set at server start
    "language": "en"
  },
  "tts": {
    "url": "http://localhost:7422",
    "voice": "default",       // or a custom voice name
    "speed": 1.0
  },
  "vad": {
    "silenceThresholdMs": 800,
    "energyThreshold": 0.01
  },
  "conversation": {
    "maxContextExchanges": 20,
    "triggerMode": "keyword",  // "keyword" or "always"
    "triggerWords": ["lobs", "hey lobs"]
  }
}
```

## Model Swapping

Both services are designed for easy model swapping:

### STT Models (whisper.cpp)
```bash
# Download models
cd lobs-voice/stt/models/
sh download-model.sh tiny.en    # 75MB, fastest, 99%+ accuracy
sh download-model.sh base.en    # 142MB, great balance (default)
sh download-model.sh small.en   # 466MB, highest accuracy
sh download-model.sh large-v3-turbo  # 1.5GB, best quality

# Generate Core ML model for ANE acceleration (optional but recommended)
sh generate-coreml.sh base.en

# Switch model — restart with different --model flag
./start-stt.sh --model models/ggml-small.en.bin
```

### TTS Models (Chatterbox)
Chatterbox loads from HuggingFace cache. The TTS service wraps whatever model Chatterbox provides.
Future: support additional TTS backends (Piper, Bark, etc.) behind the same OpenAI-compatible API.

## Directory Structure

```
lobs-voice/
├── ARCHITECTURE.md          This file
├── README.md
├── stt/                     whisper.cpp STT server
│   ├── Makefile             Build whisper.cpp with Core ML
│   ├── models/              Model files (.bin + .mlmodelc)
│   │   └── download-model.sh
│   ├── generate-coreml.sh   Generate Core ML encoder model
│   └── start-stt.sh         Launch script with config
├── tts/                     Chatterbox TTS server
│   ├── server.py            FastAPI TTS service
│   ├── requirements.txt
│   ├── voices/              Voice reference audio for cloning
│   └── start-tts.sh         Launch script
└── scripts/
    ├── start-all.sh         Start both services
    ├── stop-all.sh          Stop both services
    └── health-check.sh      Check both services
```

## Dependencies (lobs-core additions)

```json
{
  "@discordjs/voice": "^0.18.0",
  "@discordjs/opus": "^0.9.0",
  "libsodium-wrappers": "^0.7.15"
}
```

Plus `GatewayIntentBits.GuildVoiceStates` added to the Discord client intents.

## Security

- All services listen on localhost only (127.0.0.1)
- No authentication needed for local services
- Voice data is never persisted unless explicitly configured
- Transcripts are kept in memory only (per-session)

## Future Enhancements

- **Streaming TTS:** Chatterbox sentence-level streaming → play audio while still generating
- **Multi-language:** Switch whisper model to multilingual variant
- **Voice cloning presets:** Pre-configured voices selectable via Discord command
- **Recording mode:** Optionally save transcripts to memory system
- **Multi-guild:** Support concurrent voice sessions across guilds
- **Interrupt handling:** If user speaks while Lobs is speaking, stop playback and listen
