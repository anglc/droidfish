#!/usr/bin/env bash
# zts006 编排：编译 APK → 本机手机 AVD → 远程 zts014 平板+电视 AVD
# 已运行的 AVD 不会重复启动；测试结束后保持运行。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

REMOTE_HOST="${COLA_REMOTE_HOST:-zts014}"
REMOTE_USER="${COLA_REMOTE_USER:-zts014}"
REMOTE_ROOT="${COLA_REMOTE_ROOT:-/home/zts014/cola-chess}"

BUILD_APK="${COLA_BUILD:-1}"
APK="$ROOT/DroidFishApp/build/outputs/apk/debug/DroidFishApp-debug.apk"

log() { echo "[cola-pipeline] $*"; }
fail() { echo "[cola-pipeline] FAIL: $*" >&2; exit 1; }

sync_remote_assets() {
  log "同步脚本与配置到 ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ROOT} ..."
  ssh -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '$REMOTE_ROOT/scripts' '$REMOTE_ROOT/build'"
  scp -q "$ROOT/cola-avd.properties" \
      "$ROOT/scripts/cola-avd-node.sh" \
      "$ROOT/scripts/cola-recreate-avds.sh" \
      "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ROOT}/"
  scp -q "$ROOT/scripts/cola-avd-node.sh" \
      "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ROOT}/scripts/cola-avd-node.sh"
  scp -q "$APK" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ROOT}/ColaChess-debug.apk"
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "chmod +x '$REMOTE_ROOT/scripts/cola-avd-node.sh' '$REMOTE_ROOT/scripts/cola-recreate-avds.sh' 2>/dev/null || true"
}

remote_ready() {
  ssh -o BatchMode=yes -o ConnectTimeout=8 "${REMOTE_USER}@${REMOTE_HOST}" \
    "test -x '$REMOTE_ROOT/scripts/cola-avd-node.sh' && test -d \"\${ANDROID_HOME:-\$HOME/Android/Sdk}/emulator\"" 2>/dev/null
}

mkdir -p "$ROOT/build"
if [[ "$BUILD_APK" == "1" ]]; then
  log "编译 debug APK..."
  (cd "$ROOT" && export JAVA_HOME && ./gradlew :DroidFishApp:assembleDebug -q)
fi
[[ -f "$APK" ]] || fail "找不到 $APK"
cp -f "$APK" "$ROOT/ColaChess-debug.apk"

log "=== 本机 zts006：ColaChess_Phone ==="
export COLA_STOP_OLD_EMULATORS=0
export COLA_DEVICES=phone
export COLA_APK="$APK"
export COLA_BUILD=0
bash "$ROOT/scripts/cola-avd-node.sh" || fail "手机 AVD 冒烟失败"

if remote_ready; then
  sync_remote_assets
  log "=== 远程 ${REMOTE_HOST}：平板 + 电视 ==="
  ssh "${REMOTE_USER}@${REMOTE_HOST}" \
    "export ANDROID_HOME=\"\${ANDROID_HOME:-\$HOME/Android/Sdk}\" COLA_APK='$REMOTE_ROOT/ColaChess-debug.apk' COLA_DEVICES=tablet,tv COLA_STOP_OLD_EMULATORS=0 COLA_PROPS='$REMOTE_ROOT/cola-avd.properties' && bash '$REMOTE_ROOT/scripts/cola-avd-node.sh'" \
    || fail "远程平板/TV 冒烟失败"
else
  log "远程 ${REMOTE_HOST} 未配置 Android SDK/脚本（见 scripts/cola-bootstrap-zts014.sh），已跳过平板/电视。"
  log "仅本机手机 AVD 已测试并保持运行。"
fi

log "========================================"
log "流水线完成。模拟器默认保持开启，便于手动试用。"
log "本机: adb devices"
log "远程: ssh ${REMOTE_USER}@${REMOTE_HOST} adb devices"