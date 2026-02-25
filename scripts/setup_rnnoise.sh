#!/usr/bin/env bash
# setup_rnnoise.sh — Download RNNoise source for Android NDK compilation
#
# Usage: bash scripts/setup_rnnoise.sh
# Run this once before building the APK. Requires git.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="$PROJECT_DIR/android/app/src/main/cpp/rnnoise"

echo "MicStream — Phase 4: RNNoise setup"
echo "Target: $TARGET_DIR"

if [ -d "$TARGET_DIR/.git" ]; then
    echo "RNNoise source already present. Pulling latest..."
    git -C "$TARGET_DIR" pull --ff-only
    echo "Done."
    exit 0
fi

if [ -d "$TARGET_DIR" ]; then
    echo "Directory exists but is not a git repo — removing and re-cloning..."
    rm -rf "$TARGET_DIR"
fi

echo "Cloning xiph/rnnoise (shallow)..."
git clone --depth 1 https://github.com/xiph/rnnoise.git "$TARGET_DIR"

echo ""
echo "Downloading RNNoise model weights..."
cd "$TARGET_DIR" && bash download_model.sh
cd "$PROJECT_DIR"

echo ""
echo "RNNoise source and model ready at:"
echo "  $TARGET_DIR"
echo ""
echo "Next step — build the release APK:"
echo "  flutter build apk --release"
