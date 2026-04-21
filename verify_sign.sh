#!/bin/bash
# 验证 PromptWise 的签名信息（支持 .app / .dmg）
# 用法：
#   ./verify_sign.sh                              # 默认检查 ./PromptWise.app
#   ./verify_sign.sh /Applications/PromptWise.app
#   ./verify_sign.sh ./PromptWise-1.0.0.dmg

set -euo pipefail

TARGET="${1:-./PromptWise.app}"
TMP_MOUNT=""

cleanup() {
  if [[ -n "$TMP_MOUNT" && -d "$TMP_MOUNT" ]]; then
    hdiutil detach "$TMP_MOUNT" -quiet >/dev/null 2>&1 || true
    rmdir "$TMP_MOUNT" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

resolve_app_from_dmg() {
  local dmg="$1"
  TMP_MOUNT="$(mktemp -d /tmp/promptwise-dmg.XXXXXX)"
  hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$TMP_MOUNT" -quiet
  local app
  app="$(find "$TMP_MOUNT" -maxdepth 2 -name "*.app" -print | head -n 1)"
  if [[ -z "$app" ]]; then
    echo "✘ DMG 中未找到 .app" >&2
    exit 1
  fi
  echo "$app"
}

if [[ ! -e "$TARGET" ]]; then
  echo "✘ 路径不存在：$TARGET" >&2
  exit 1
fi

if [[ "$TARGET" == *.dmg ]]; then
  APP_PATH="$(resolve_app_from_dmg "$TARGET")"
else
  APP_PATH="$TARGET"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "✘ 不是 .app 目录：$APP_PATH" >&2
  exit 1
fi

echo "▶ 检查目标：$APP_PATH"
echo ""

echo "== codesign -dv =="
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed 's/^/  /'
echo ""

echo "== codesign verify =="
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | sed 's/^/  /'
echo ""

echo "== 可用 codesign identities（默认 keychain 列表）=="
security find-identity -p codesigning 2>&1 | sed 's/^/  /'
echo ""

echo "提示：本地自签名通常会显示 NOT_TRUSTED，这是预期现象；核心看 Signature 不为 adhoc。"
