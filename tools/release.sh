#!/usr/bin/env bash
# Builds a signed release and stages it in the SmarterASP package.
#
# Release code = date + time concatenated (yyyyMMddHHmm, e.g. 202610082145). It is:
#   - part of the Android versionName (Settings > Apps shows "1.2.0-202610082145"),
#   - shown inside the app (compiled in as RELEASE_CODE),
#   - in the APK file names and on the download page.
# Android's versionCode must stay below 2,100,000,000, so it uses yyMMddHH (e.g. 26100821),
# which still always increases.
#
# Usage (Git Bash):  tools/release.sh [package-dir]     default: ../ExpenseTracker-SmarterASP
set -euo pipefail
cd "$(dirname "$0")/.."

STAMP=$(date +%Y%m%d%H%M)
CODE=$(date +%y%m%d%H)
NAME=$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
OUT=${1:-../ExpenseTracker-SmarterASP}

echo "release $NAME  code $STAMP  (versionCode $CODE)"
flutter build apk --release --split-per-abi \
  --build-name="$NAME-$STAMP" --build-number="$CODE" \
  --dart-define=RELEASE_CODE="$STAMP" --dart-define=APP_VERSION="$NAME"

APK=build/app/outputs/flutter-apk
for dir in "$OUT/server/public" "$OUT/site"; do
  [ -d "$dir" ] || continue
  rm -f "$dir"/Masarefy_*.apk
  cp "$APK/app-arm64-v8a-release.apk" "$dir/Masarefy_${STAMP}_arm64.apk"
  cp "$APK/app-armeabi-v7a-release.apk" "$dir/Masarefy_${STAMP}_arm32.apk"
  if [ -f "$dir/index.html" ]; then
    sed -i -E \
      -e "s/Masarefy_[A-Za-z0-9._-]*_arm64\.apk/Masarefy_${STAMP}_arm64.apk/g" \
      -e "s/Masarefy_[A-Za-z0-9._-]*_arm32\.apk/Masarefy_${STAMP}_arm32.apk/g" \
      -e "s/الإصدار [^–]*–/الإصدار ${NAME} (${STAMP}) –/" \
      "$dir/index.html"
  fi
done
echo "$STAMP" > "$OUT/RELEASE.txt"
echo "staged Masarefy_${STAMP}_*.apk in $OUT"
