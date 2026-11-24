#!/usr/bin/env bash
# 在 zts014 上一次性安装 API 34 镜像并创建平板/电视 AVD（在 zts006 上执行）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_HOST="${1:-zts014}"
REMOTE_USER="${2:-zts014}"
REMOTE_ROOT="/home/$REMOTE_USER/cola-chess"

log() { echo "[bootstrap] $*"; }

log "同步 cola-chess 脚本到 $REMOTE_USER@$REMOTE_HOST ..."
ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_ROOT/scripts' ~/Android/Sdk"
scp -q "$ROOT/cola-avd.properties" "$ROOT/scripts/cola-recreate-avds.sh" "$ROOT/scripts/cola-avd-node.sh" \
  "$REMOTE_USER@$REMOTE_HOST:$REMOTE_ROOT/"
ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_ROOT/scripts' && cp -f '$REMOTE_ROOT/cola-avd-node.sh' '$REMOTE_ROOT/scripts/' 2>/dev/null || mv '$REMOTE_ROOT/cola-avd-node.sh' '$REMOTE_ROOT/scripts/'"

log "安装 Android SDK 组件（首次较慢）..."
ssh "$REMOTE_USER@$REMOTE_HOST" bash -s <<'REMOTE'
set -euo pipefail
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  echo "请先在 $REMOTE_HOST 安装 Android SDK cmdline-tools 到 \$ANDROID_HOME/cmdline-tools/latest"
  echo "或从 zts006 同步: rsync -a \$HOME/Android/Sdk/ zts014:~/Android/Sdk/"
  exit 1
fi
yes | sdkmanager \
  "platform-tools" "emulator" "platforms;android-34" \
  "system-images;android-34;google_apis;x86_64" \
  "system-images;android-34;android-tv;x86"
chmod +x "$HOME/cola-chess/scripts/cola-recreate-avds.sh"
ANDROID_HOME="$ANDROID_HOME" bash "$HOME/cola-chess/scripts/cola-recreate-avds.sh"
REMOTE

log "zts014 引导完成。可运行: COLA_BUILD=0 ./scripts/cola-avd-pipeline.sh"