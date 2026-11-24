#!/usr/bin/env bash
# 按 cola-avd.properties 重建 API 34 三台 AVD
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROPS="$ROOT/cola-avd.properties"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

PHONE_IMG="system-images;android-34;google_apis;x86_64"
TV_IMG="system-images;android-34;android-tv;x86"
PHONE_DEV="pixel_8"
TABLET_DEV="pixel_tablet"
TV_DEV="tv_1080p"

if [[ -f "$PROPS" ]]; then
  PHONE_IMG="$(grep '^avd\.phone\.image=' "$PROPS" | cut -d= -f2-)"
  TV_IMG="$(grep '^avd\.tv\.image=' "$PROPS" | cut -d= -f2-)"
  PHONE_DEV="$(grep '^avd\.phone\.device=' "$PROPS" | cut -d= -f2-)"
  TABLET_DEV="$(grep '^avd\.tablet\.device=' "$PROPS" | cut -d= -f2-)"
  TV_DEV="$(grep '^avd\.tv\.device=' "$PROPS" | cut -d= -f2-)"
fi

PHONE_SYS="$ANDROID_HOME/system-images/android-34/google_apis/x86_64"
TV_SYS="$ANDROID_HOME/system-images/android-34/android-tv/x86"
[[ -d "$PHONE_SYS" ]] || {
  echo "请先安装: sdkmanager \"system-images;android-34;google_apis;x86_64\"" >&2
  exit 1
}
[[ -d "$TV_SYS" ]] || {
  echo "请先安装: sdkmanager \"system-images;android-34;android-tv;x86\"" >&2
  exit 1
}

for n in ColaChess_Phone ColaChess_Tablet ColaChess_TV; do
  avdmanager delete avd -n "$n" 2>/dev/null || true
done

echo no | avdmanager create avd -n ColaChess_Phone -k "$PHONE_IMG" -d "$PHONE_DEV" --abi google_apis/x86_64
echo no | avdmanager create avd -n ColaChess_Tablet -k "$PHONE_IMG" -d "$TABLET_DEV" --abi google_apis/x86_64
echo no | avdmanager create avd -n ColaChess_TV -k "$TV_IMG" -d "$TV_DEV" --abi android-tv/x86

avdmanager list avd | grep -A5 ColaChess