#!/usr/bin/env bash
# ColaChess：启动三类 AVD 并安装 debug APK
set -euo pipefail
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
APK="${COLACHESS_APK:-$HOME/cola-chess/ColaChess-debug.apk}"

usage() {
  echo "用法: COLACHESS_APK=path $0 <phone|tablet|tv|list|install-all>"
  echo "  phone / tablet / tv  后台启动对应模拟器"
  echo "  list                   avdmanager list avd"
  echo "  install-all            对当前在线的全部设备安装 APK"
}

case "${1:-list}" in
  list)
    avdmanager list avd
    exit 0
    ;;
  phone)
    emulator -avd ColaChess_Phone -netdelay none -netspeed full &
    ;;
  tablet)
    emulator -avd ColaChess_Tablet -netdelay none -netspeed full &
    ;;
  tv)
    emulator -avd ColaChess_TV -netdelay none -netspeed full &
    ;;
  install-all)
  if [[ ! -f "$APK" ]]; then
    echo "找不到 APK: $APK" >&2
    exit 1
  fi
  adb wait-for-device
  for s in $(adb devices | awk '/device$/{print $1}'); do
    echo "安装到 $s ..."
    adb -s "$s" install -r "$APK" || true
  done
  exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac