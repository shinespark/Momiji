#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
dest="Resources/zenzai/ggml-model-Q5_K_M.gguf"
if [[ -f "$dest" ]]; then
    exit 0
fi
mkdir -p "$(dirname "$dest")"
curl -fL --progress-bar -o "$dest.tmp" \
    "https://huggingface.co/Miwa-Keita/zenz-v3.2-small-gguf/resolve/main/ggml-model-Q5_K_M.gguf"
mv "$dest.tmp" "$dest"
