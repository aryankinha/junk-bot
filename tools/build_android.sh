#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
export JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home}"
mkdir -p build
ensure_gradle_template() {
  if [[ ! -f android/build/build.gradle ]]; then python3 tools/fetch_android_template.py; fi
  chmod +x android/build/gradlew
}
case "${1:-debug}" in
  debug) "$GODOT_BIN" --headless --path . --export-debug "Android Debug" build/scrap_dragon_debug.apk ;;
  ads) ensure_gradle_template; "$GODOT_BIN" --headless --path . --export-debug "Android Test Ads" build/scrap_dragon_test_ads.apk ;;
  release)
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Set the real release upload keystore path}"
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Set the release key alias}"
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Set the release key password}"
    ensure_gradle_template
    "$GODOT_BIN" --headless --path . --export-release "Android Release AAB" build/scrap_dragon_release.aab ;;
  sideload)
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Set the release upload keystore path}"
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Set the release key alias}"
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Set the release key password}"
    "$GODOT_BIN" --headless --path . --export-release "Android Sideload (arm64)" build/scrap_dragon_sideload.apk ;;
  *) echo 'Usage: tools/build_android.sh debug|ads|sideload|release'; exit 2 ;;
esac
