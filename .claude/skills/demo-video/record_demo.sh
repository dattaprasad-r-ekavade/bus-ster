#!/usr/bin/env bash
# Records the scripted demo tour (integration_test/demo_tour_test.dart) on the
# Android emulator and encodes a shareable MP4.
#
# Usage: record_demo.sh [output_dir]   (default: build/demo)
set -u
export MSYS_NO_PATHCONV=1   # stop Git Bash rewriting /sdcard paths

ROOT="$(git rev-parse --show-toplevel)" || exit 1
cd "$ROOT"
OUT="${1:-$ROOT/build/demo}"
mkdir -p "$OUT"

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$LOCALAPPDATA/Android/sdk}}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
AVD="${BUSSTER_AVD:-Busster_QA_API35}"
DEVICE="${BUSSTER_DEVICE:-emulator-5554}"
PKG=com.busster.busster

ensure_emulator() {
  if "$ADB" devices | grep -q "^$DEVICE[[:space:]]*device"; then return 0; fi
  echo "Booting $AVD..."
  "$EMULATOR" -avd "$AVD" -no-snapshot-save -no-audio -no-boot-anim >/dev/null 2>&1 &
  "$ADB" -s "$DEVICE" wait-for-device
  until [ "$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
  done
  sleep 5
}

ensure_emulator
"$ADB" -s "$DEVICE" shell pm clear "$PKG" >/dev/null 2>&1

flutter test integration_test/demo_tour_test.dart -d "$DEVICE" >"$OUT/demo_test.log" 2>&1 &
TEST_PID=$!

# Start recording once the app process exists, so the build time isn't filmed.
for _ in $(seq 1 600); do
  "$ADB" -s "$DEVICE" shell pidof "$PKG" >/dev/null 2>&1 && break
  sleep 0.5
done
"$ADB" -s "$DEVICE" shell screenrecord --bit-rate 12000000 --time-limit 180 /sdcard/busster_demo.mp4 &
REC_PID=$!

wait $TEST_PID
TEST_STATUS=$?
sleep 2
"$ADB" -s "$DEVICE" shell pkill -INT screenrecord
sleep 3
wait $REC_PID 2>/dev/null

if [ $TEST_STATUS -ne 0 ]; then
  echo "Demo tour test failed; see $OUT/demo_test.log"
  tail -n 20 "$OUT/demo_test.log"
  exit 1
fi

"$ADB" -s "$DEVICE" pull /sdcard/busster_demo.mp4 "$OUT/demo_raw.mp4" >/dev/null || exit 1
STAMP="$(date +%Y%m%d_%H%M)"
FINAL="$OUT/busster_demo_$STAMP.mp4"
ffmpeg -v error -y -ss 2.5 -i "$OUT/demo_raw.mp4" -vf "scale=720:-2" \
  -c:v libx264 -crf 22 -preset slow -pix_fmt yuv420p -movflags +faststart "$FINAL" || exit 1
ffmpeg -v error -y -i "$FINAL" -vf "fps=1/5,scale=180:-1,tile=6x3" -frames:v 1 "$OUT/contact_$STAMP.png"

echo "VIDEO   $FINAL"
echo "SHEET   $OUT/contact_$STAMP.png"
