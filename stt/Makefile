##
## lobs-voice STT — whisper.cpp build with Core ML support
##
## Usage:
##   make          Build whisper.cpp (clone if needed)
##   make clone    Clone whisper.cpp repo only
##   make build    Build whisper.cpp with Core ML
##   make clean    Remove build artifacts (keeps source + models)
##   make nuke     Remove everything (whisper.cpp dir entirely)
##   make model    Download the default model (base.en)
##   make status   Show build status
##

WHISPER_DIR  := whisper.cpp
BUILD_DIR    := $(WHISPER_DIR)/build
SERVER_BIN   := $(BUILD_DIR)/bin/whisper-server
WHISPER_REPO := https://github.com/ggml-org/whisper.cpp
DEFAULT_MODEL := base.en
MODEL_FILE   := $(WHISPER_DIR)/models/ggml-$(DEFAULT_MODEL).bin

# Number of parallel build jobs (default: system core count)
JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

.PHONY: all clone build clean nuke model status help

all: build

help:
	@grep '^##' Makefile | sed 's/^## \?//'

## ─── Clone ──────────────────────────────────────────────────────────────

clone: $(WHISPER_DIR)/.git

$(WHISPER_DIR)/.git:
	@echo "═══ Cloning whisper.cpp ═══"
	git clone --depth 1 $(WHISPER_REPO) $(WHISPER_DIR)
	@echo "✓ whisper.cpp cloned"

## ─── Build ──────────────────────────────────────────────────────────────

build: $(SERVER_BIN)

$(SERVER_BIN): $(WHISPER_DIR)/.git
	@echo "═══ Building whisper.cpp with Core ML support ═══"
	cd $(WHISPER_DIR) && cmake -B build \
		-DWHISPER_COREML=1 \
		-DCMAKE_BUILD_TYPE=Release
	cd $(WHISPER_DIR) && cmake --build build -j$(JOBS) --config Release
	@if [ -f "$(SERVER_BIN)" ]; then \
		echo "✓ whisper-server built: $(SERVER_BIN)"; \
	else \
		echo "✗ Build failed — whisper-server binary not found"; \
		exit 1; \
	fi

## ─── Model ──────────────────────────────────────────────────────────────

model: $(MODEL_FILE)

$(MODEL_FILE): $(WHISPER_DIR)/.git
	@echo "═══ Downloading default model: $(DEFAULT_MODEL) ═══"
	cd models && bash download-model.sh $(DEFAULT_MODEL)

## ─── Clean ──────────────────────────────────────────────────────────────

clean:
	@echo "═══ Cleaning build artifacts ═══"
	rm -rf $(BUILD_DIR)
	@echo "✓ Build directory removed (source + models preserved)"

nuke:
	@echo "═══ Removing whisper.cpp entirely ═══"
	rm -rf $(WHISPER_DIR)
	@echo "✓ whisper.cpp directory removed"

## ─── Status ─────────────────────────────────────────────────────────────

status:
	@echo "── whisper.cpp STT build status ──"
	@if [ -d "$(WHISPER_DIR)/.git" ]; then \
		echo "  Repo:    ✓ cloned"; \
		cd $(WHISPER_DIR) && echo "  Commit:  $$(git log --oneline -1)"; \
	else \
		echo "  Repo:    ✗ not cloned"; \
	fi
	@if [ -f "$(SERVER_BIN)" ]; then \
		echo "  Binary:  ✓ $(SERVER_BIN)"; \
	else \
		echo "  Binary:  ✗ not built"; \
	fi
	@echo "  Models:"
	@if ls models/ggml-*.bin 1>/dev/null 2>&1; then \
		for f in models/ggml-*.bin; do \
			size=$$(du -h "$$f" | cut -f1); \
			echo "    ✓ $$(basename $$f) ($$size)"; \
		done; \
	else \
		echo "    (none downloaded)"; \
	fi
	@if ls $(WHISPER_DIR)/models/*-encoder.mlmodelc 1>/dev/null 2>&1; then \
		echo "  Core ML:"; \
		for d in $(WHISPER_DIR)/models/*-encoder.mlmodelc; do \
			echo "    ✓ $$(basename $$d)"; \
		done; \
	else \
		echo "  Core ML: (no encoder models generated)"; \
	fi
