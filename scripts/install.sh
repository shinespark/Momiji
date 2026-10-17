#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/fetch-zenzai-model.sh

swift build -c release --product Momiji
bin="$(swift build -c release --show-bin-path)"

app="build/Momiji.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/zenzai" "$app/Contents/Frameworks"
cp "$bin/Momiji" "$app/Contents/MacOS/Momiji"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/main.tiff "$app/Contents/Resources/main.tiff"
cp Resources/zenzai/ggml-model-Q5_K_M.gguf "$app/Contents/Resources/zenzai/"
for bundle in "$bin"/*.bundle; do
    cp -R "$bundle" "$app/Contents/Resources/"
done
cp -R "$bin/llama.framework" "$app/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/Momiji"

codesign --force --deep --sign "Apple Development" "$app"
codesign --verify --deep --strict "$app"

dest="$HOME/Library/Input Methods/Momiji.app"
killall Momiji 2>/dev/null || true
rm -rf "$dest"
cp -R "$app" "$dest"
echo "installed: $dest"
