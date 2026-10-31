#!/bin/bash
# Only the developer-owned game package is touched. No device setting changes.
set -euo pipefail
cd "$(dirname "$0")/.."
SERIAL="${1:?Usage: tools/phone_perf_session.sh SERIAL preflight|install|run|collect|screenshot [seconds]}"
PHASE="${2:-preflight}"
PKG='com.aryankinha.scrapdragon'
[[ "$SERIAL" != emulator-* && "$SERIAL" != *[[:space:]]* ]] || { echo 'Use one physical phone serial'; exit 2; }
OUT="${PHONE_RESULT_DIR:-results/phone_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT"
focus_ok() {
  adb -s "$SERIAL" shell 'dumpsys window | grep mCurrentFocus' | grep -q "$PKG"
}
guard() {
  local battery thermal temperature level minimum
  minimum="${1:-25}"
  battery="$(adb -s "$SERIAL" shell dumpsys battery)"
  temperature="$(awk '/temperature:/{print $2}' <<< "$battery" | tr -d '\r')"
  level="$(awk '/level:/{print $2}' <<< "$battery" | tr -d '\r')"
  thermal="$(adb -s "$SERIAL" shell dumpsys thermalservice)"
  printf 'battery_level=%s temperature_tenths=%s\n' "$level" "$temperature" >> "$OUT/guard.log"
  [[ -n "$temperature" && "$temperature" -lt 430 && -n "$level" && "$level" -ge "$minimum" ]] || { echo 'Stopped: battery/temperature threshold'; exit 1; }
  if grep -Eq 'Thermal Status: [3-6]' <<< "$thermal"; then echo 'Stopped: severe thermal state'; exit 1; fi
}
case "$PHASE" in
 preflight)
  devices="$(adb devices -l)"
  count="$(awk 'NR>1 && $2=="device" {n++} END {print n+0}' <<< "$devices")"
  [[ "$count" == 1 ]] || { echo 'Exactly one physical phone must be connected'; exit 1; }
  for prop in ro.product.model ro.product.manufacturer ro.build.version.release ro.build.version.sdk ro.soc.model ro.board.platform; do
   printf '%s=' "$prop" >> "$OUT/device_facts.txt"
   adb -s "$SERIAL" shell getprop "$prop" >> "$OUT/device_facts.txt"
  done
  guard 50
  echo 'Preflight saved. Phone must be unlocked, cool, and above 50% battery before a measured run.'
  ;;
 install)
  if adb -s "$SERIAL" shell pm path "$PKG" | grep -q 'package:'; then
   adb -s "$SERIAL" install -r build/scrap_dragon_debug.apk
  else
   adb -s "$SERIAL" install build/scrap_dragon_debug.apk
  fi
  ;;
 run)
  SECONDS_TO_RUN="${3:-180}"
  [[ "$SECONDS_TO_RUN" =~ ^[0-9]+$ && "$SECONDS_TO_RUN" -ge 20 && "$SECONDS_TO_RUN" -le 600 ]] || exit 2
  guard
  adb -s "$SERIAL" shell am force-stop "$PKG"
  adb -s "$SERIAL" shell am start -W -n "$PKG/com.godot.game.GodotAppLauncher" > "$OUT/launch.txt"
  adb -s "$SERIAL" shell dumpsys meminfo "$PKG" > "$OUT/meminfo_start.txt"
  sleep 3
  elapsed=0
  while [[ "$elapsed" -lt "$SECONDS_TO_RUN" ]]; do
   if ! focus_ok; then echo 'INVALID: game lost focus or phone is locked' >> "$OUT/focus_events.log"; exit 1; fi
   guard
   sleep 20
   elapsed=$((elapsed + 20))
  done
  adb -s "$SERIAL" shell dumpsys meminfo "$PKG" > "$OUT/meminfo_end.txt"
  adb -s "$SERIAL" exec-out run-as "$PKG" cat files/perf.json > "$OUT/perf.json"
  adb -s "$SERIAL" exec-out run-as "$PKG" cat files/perf_frames.csv > "$OUT/perf_frames.csv"
  adb -s "$SERIAL" exec-out run-as "$PKG" cat files/telemetry.jsonl > "$OUT/telemetry.jsonl"
  ;;
 stress)
  attempt="${3:-1}"
  [[ "$attempt" =~ ^[1-3]$ ]] || exit 2
  marker="scrap_stress_a$attempt"
  adb -s "$SERIAL" exec-out run-as "$PKG" touch "files/$marker"
  PHONE_RESULT_DIR="$OUT" "$0" "$SERIAL" run 70
  ;;
 collect)
  adb -s "$SERIAL" exec-out run-as "$PKG" cat files/perf.json > "$OUT/perf.json"
  adb -s "$SERIAL" exec-out run-as "$PKG" cat files/perf_frames.csv > "$OUT/perf_frames.csv"
  adb -s "$SERIAL" shell dumpsys meminfo "$PKG" > "$OUT/meminfo_end.txt"
  ;;
 screenshot)
  focus_ok || { echo 'Screenshot skipped: game not foreground'; exit 1; }
  adb -s "$SERIAL" exec-out screencap -p > "$OUT/screen_$(date +%H%M%S).png"
  ;;
 *) echo 'Unknown phase'; exit 2 ;;
esac
printf 'Results: %s\n' "$OUT"
