#!/usr/bin/env bash
# zts006 等 16G 主机：用较轻参数重启手机 AVD，减轻「Emulator 无响应」
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHONE_AVD="${COLA_PHONE_AVD:-ColaChess_Phone}"
PHONE_INI="$HOME/.android/avd/${PHONE_AVD}.avd/config.ini"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

if [[ -f "$PHONE_INI" ]]; then
  sed -i 's/^hw\.ramSize *= *.*/hw.ramSize = 1536M/' "$PHONE_INI"
fi

export DISPLAY="${DISPLAY:-:0}"
export COLA_EMULATOR_HEADLESS=0
export COLA_EMULATOR_GPU="${COLA_EMULATOR_GPU:-host}"
export COLA_EMULATOR_NO_AUDIO=1
export COLA_DEVICES=phone
export COLA_STOP_OLD_EMULATORS=1
export COLA_PROPS="${COLA_PROPS:-$ROOT/cola-avd.properties}"
export COLA_APK="${COLA_APK:-$ROOT/ColaChess-debug.apk}"
exec bash "$ROOT/scripts/cola-avd-node.sh"