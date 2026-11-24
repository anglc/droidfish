#!/usr/bin/env bash
# 在本机确保指定 ColaChess AVD 已运行 → 安装 APK → 冒烟测试（不关闭 AVD）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
PROPS="${COLA_PROPS:-$ROOT/cola-avd.properties}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

PKG="com.anglc.colachess"
ACTIVITY="org.petero.droidfish.DroidFish"
APK="${COLA_APK:-$ROOT/ColaChess-debug.apk}"
BOOT_TIMEOUT="${COLA_BOOT_TIMEOUT_SEC:-300}"
# 默认：不杀已有模拟器；测试后保持运行
STOP_OLD="${COLA_STOP_OLD_EMULATORS:-0}"

# 逗号分隔: phone | tablet | tv | all
DEVICES="${COLA_DEVICES:-all}"

AVD_PHONE="ColaChess_Phone"
AVD_TABLET="ColaChess_Tablet"
AVD_TV="ColaChess_TV"
PORT_PHONE=5554
PORT_TABLET=5556
PORT_TV=5558

if [[ -f "$PROPS" ]]; then
  AVD_PHONE="$(grep '^avd\.phone=' "$PROPS" | cut -d= -f2- | tr -d ' ')"
  AVD_TABLET="$(grep '^avd\.tablet=' "$PROPS" | cut -d= -f2- | tr -d ' ')"
  AVD_TV="$(grep '^avd\.tv=' "$PROPS" | cut -d= -f2- | tr -d ' ')"
  PKG="$(grep '^package=' "$PROPS" | cut -d= -f2-)"
  ACTIVITY="$(grep '^activity=' "$PROPS" | cut -d= -f2-)"
fi
LAUNCH="$PKG/$ACTIVITY"

log() { echo "[cola-avd@$(hostname -s)] $*" >&2; }
fail() { echo "[cola-avd@$(hostname -s)] FAIL: $*" >&2; exit 1; }

want_device() {
  local key="$1"
  [[ "$DEVICES" == "all" ]] && return 0
  echo ",$DEVICES," | grep -qi ",$key,"
}

wait_boot() {
  local serial="$1" label="$2"
  adb -s "$serial" wait-for-device
  local n=0
  while [[ $n -lt $BOOT_TIMEOUT ]]; do
    if [[ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d $'\r')" == "1" ]]; then
      adb -s "$serial" shell input keyevent 82 >/dev/null 2>&1 || true
      return 0
    fi
    sleep 3
    n=$((n + 3))
  done
  fail "$label 开机超时 ($serial)"
}

find_serial_for_avd() {
  local avd_name="$1"
  while read -r serial _; do
    [[ "$serial" == emulator-* ]] || continue
    local n
    n="$(adb -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d $'\r')"
    if [[ "$n" == "$avd_name" ]]; then
      echo "$serial"
      return 0
    fi
  done < <(adb devices | tail -n +2)
  return 1
}

wait_emulator_port() {
  local port="$1"
  local deadline=$((SECONDS + BOOT_TIMEOUT))
  while (( SECONDS < deadline )); do
    if adb devices | awk '{print $1}' | grep -qx "emulator-$port"; then
      echo "emulator-$port"
      return 0
    fi
    sleep 2
  done
  return 1
}

start_avd_if_needed() {
  local avd="$1" port="$2" label="$3"
  local serial
  if serial="$(find_serial_for_avd "$avd" 2>/dev/null || true)"; then
    log "$label: 复用已运行 AVD $avd → $serial"
    wait_boot "$serial" "$label"
    echo "$serial"
    return 0
  fi
  log "$label: 启动 AVD $avd (端口 $port)..."
  mkdir -p "$ROOT/build"
  local emu="$ANDROID_HOME/emulator/emulator"
  [[ -x "$emu" ]] || fail "emulator 不存在: $emu"
  local headless=0
  [[ -z "${DISPLAY:-}" ]] && headless=1
  [[ "${COLA_EMULATOR_HEADLESS:-auto}" == "1" ]] && headless=1
  [[ "${COLA_EMULATOR_HEADLESS:-auto}" == "0" ]] && headless=0
  local gpu="${COLA_EMULATOR_GPU:-}"
  if [[ -z "$gpu" ]]; then
    if [[ $headless -eq 1 ]]; then
      gpu="swiftshader_indirect"
    elif [[ -r /dev/kvm ]] && id -nG 2>/dev/null | grep -qw kvm; then
      gpu="host"
    else
      gpu="swiftshader_indirect"
    fi
  fi
  local emu_extra=(-no-boot-anim -gpu "$gpu" -no-snapshot-save -no-metrics)
  [[ "${COLA_EMULATOR_NO_AUDIO:-1}" == "1" ]] && emu_extra+=(-no-audio)
  if [[ $headless -eq 1 ]]; then
    export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
    unset DISPLAY
    emu_extra+=(-no-window)
  fi
  nohup "$emu" -avd "$avd" -port "$port" "${emu_extra[@]}" \
    >>"$ROOT/build/cola-emulator-$avd.log" 2>&1 &
  serial="$(wait_emulator_port "$port")" || fail "$label 未出现在 adb"
  wait_boot "$serial" "$label"
  echo "$serial"
}

smoke_test() {
  local serial="$1" label="$2" device_key="${3:-}"
  [[ -f "$APK" ]] || fail "APK 不存在: $APK"
  if [[ "$device_key" == "tv" ]]; then
    adb -s "$serial" shell settings put global package_verifier_enable 0 2>/dev/null || true
    adb -s "$serial" shell settings put global upload_apk_enable 0 2>/dev/null || true
    adb -s "$serial" shell pm disable-user --user 0 com.android.vending 2>/dev/null || true
  fi
  log "[$label] install -r"
  adb -s "$serial" install -r "$APK" >/dev/null || fail "[$label] install 失败"
  adb -s "$serial" shell am force-stop "$PKG" || true
  if [[ "$device_key" == "tv" ]]; then
  if ! adb -s "$serial" shell cmd package query-activities --brief \
      -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER 2>/dev/null \
      | tr -d $'\r' | grep -q "$PKG"; then
      fail "[$label] 未出现在 Leanback Launcher（检查 manifest）"
    fi
    log "[$label] 以 LEANBACK_LAUNCHER 启动（电视主屏点开即玩）"
    adb -s "$serial" shell am start -a android.intent.action.MAIN \
      -c android.intent.category.LEANBACK_LAUNCHER -n "$LAUNCH" -W >/dev/null 2>&1 || true
  else
    adb -s "$serial" shell am start -n "$LAUNCH" -W >/dev/null 2>&1 || true
  fi
  sleep 5
  local pid
  pid="$(adb -s "$serial" shell pidof "$PKG" 2>/dev/null | tr -d $'\r' | awk '{print $1}')"
  [[ -n "$pid" && "$pid" != "0" ]] || fail "[$label] 进程未运行"
  log "[$label] 冒烟通过 pid=$pid"
}

if [[ "$STOP_OLD" == "1" ]]; then
  log "COLA_STOP_OLD_EMULATORS=1，关闭全部 emulator..."
  adb devices | awk '/^emulator-/{print $1}' | while read -r s; do
    adb -s "$s" emu kill 2>/dev/null || true
  done
  sleep 2
fi

[[ -f "$APK" ]] || fail "请先提供 APK: $APK"

FAILED=0
run_one() {
  local key="$1" avd="$2" port="$3" label="$4"
  want_device "$key" || return 0
  if serial="$(start_avd_if_needed "$avd" "$port" "$label")"; then
    if smoke_test "$serial" "$label" "$key"; then
      log "[$label] 完成，AVD 保持运行: $serial"
    else
      FAILED=1
    fi
  else
    FAILED=1
  fi
}

run_one phone "$AVD_PHONE" "$PORT_PHONE" "手机"
run_one tablet "$AVD_TABLET" "$PORT_TABLET" "平板"
run_one tv "$AVD_TV" "$PORT_TV" "电视"

[[ $FAILED -eq 0 ]] || exit 1
log "节点测试成功（模拟器未关闭）"