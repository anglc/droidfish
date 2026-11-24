#!/usr/bin/env bash
# 从 zts006 同步 Android SDK + 平板/电视 AVD 到 zts014，并后台启动两台模拟器
set -euo pipefail
REMOTE="${COLA_REMOTE:-zts014}"
REMOTE_USER="${COLA_REMOTE_USER:-zts014}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log() { echo "[cola-sync] $*"; }

log "同步 Android SDK 到 ${REMOTE_USER}@${REMOTE}（体积大，请耐心等待）..."
ssh "${REMOTE_USER}@${REMOTE}" "mkdir -p ~/Android ~/.android/avd"
rsync -az --info=stats2 \
  "$HOME/Android/Sdk/" "${REMOTE_USER}@${REMOTE}:~/Android/Sdk/"

log "同步平板/电视 AVD 配置..."
for name in ColaChess_Tablet ColaChess_TV; do
  rsync -az "$HOME/.android/avd/${name}.avd/" \
    "${REMOTE_USER}@${REMOTE}:~/.android/avd/${name}.avd/"
  rsync -az "$HOME/.android/avd/${name}.ini" \
    "${REMOTE_USER}@${REMOTE}:~/.android/avd/${name}.ini"
done
log "修正远端 AVD path（/home/$(whoami) → /home/$REMOTE_USER）..."
ssh "${REMOTE_USER}@${REMOTE}" "for f in ~/.android/avd/ColaChess_*.ini; do
  sed -i 's|/home/$(whoami)|/home/'\"$REMOTE_USER\"'|g' \"\$f\"
done"

log "同步 cola-chess 脚本..."
ssh "${REMOTE_USER}@${REMOTE}" "mkdir -p ~/cola-chess/scripts"
rsync -az "$ROOT/cola-avd.properties" "${REMOTE_USER}@${REMOTE}:~/cola-chess/"
rsync -az "$ROOT/scripts/" "${REMOTE_USER}@${REMOTE}:~/cola-chess/scripts/"
ssh "${REMOTE_USER}@${REMOTE}" "chmod +x ~/cola-chess/scripts/*.sh ~/cola-chess/scripts/cola-*.sh 2>/dev/null; chmod +x ~/cola-chess/cola-*.sh 2>/dev/null || true"

log "在 zts014 启动平板 + 电视 AVD（保持运行）..."
ssh "${REMOTE_USER}@${REMOTE}" bash -s <<REMOTE
set -euo pipefail
export ANDROID_HOME="\$HOME/Android/Sdk"
export PATH="\$ANDROID_HOME/emulator:\$ANDROID_HOME/platform-tools:\$PATH"
export COLA_APK="\$HOME/cola-chess/ColaChess-debug.apk"
export COLA_DEVICES=tablet,tv
export COLA_STOP_OLD_EMULATORS=0
export COLA_PROPS="\$HOME/cola-chess/cola-avd.properties"
bash "\$HOME/cola-chess/scripts/cola-avd-node.sh"
REMOTE

log "zts014 同步与启动完成。"