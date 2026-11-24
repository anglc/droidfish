#!/usr/bin/env bash
# 在 zts014 图形桌面启动平板+电视模拟器（可见窗口）。
# 须在已登录桌面的终端里运行（NoMachine 内）。SSH 远程需先在桌面执行一次: xhost +local:
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pick_display() {
  local d
  for d in "${DISPLAY:-}" :0 :1 :0.0 :10.0; do
    [[ -z "$d" ]] && continue
    if DISPLAY="$d" XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" xdpyinfo -display "$d" >/dev/null 2>&1; then
      echo "$d"
      return 0
    fi
  done
  return 1
}
if [[ -z "${DISPLAY:-}" ]] || ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
  if d="$(pick_display)"; then
    export DISPLAY="$d"
  else
    export DISPLAY="${DISPLAY:-:0}"
  fi
fi
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export COLA_EMULATOR_HEADLESS=0
export COLA_EMULATOR_NO_AUDIO=1
# zts014 默认未加入 kvm 组时用 swiftshader；加入后可用 COLA_EMULATOR_GPU=host
export COLA_EMULATOR_GPU="${COLA_EMULATOR_GPU:-swiftshader_indirect}"
export COLA_DEVICES=tablet,tv
export COLA_STOP_OLD_EMULATORS=1
export COLA_PROPS="${COLA_PROPS:-$ROOT/cola-avd.properties}"
export COLA_APK="${COLA_APK:-$ROOT/ColaChess-debug.apk}"

if ! command -v xdpyinfo >/dev/null 2>&1; then
  echo "请安装: sudo apt install x11-utils" >&2
  exit 1
fi
if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
  echo "无法打开 $DISPLAY。请在 zts014 本机 NoMachine 终端运行此脚本，或先执行: xhost +local:" >&2
  exit 1
fi

exec bash "$ROOT/scripts/cola-avd-node.sh"