#!/bin/bash
# PromptWise - Build .app Bundle
# Usage:
#   ./build.sh              # 编译 + 打包 .app
#   ./build.sh --skip-build # 仅重新打包（跳过 swift build）
#   ./build.sh --no-sign    # 不签名（不推荐，会导致权限识别不稳定）

set -e

# ─── 颜色 ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_step()  { echo -e "${CYAN}${BOLD}▶ $1${RESET}"; }
log_ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
log_warn()  { echo -e "${YELLOW}⚠ $1${RESET}"; }
log_error() { echo -e "${RED}✘ $1${RESET}" >&2; }

# ─── 参数 ────────────────────────────────────────────────────────────
APP_NAME="PromptWise"
BUILD_DIR=".build"
APP_BUNDLE="${APP_NAME}.app"
ICON_FILE="AppIcon.icns"
DEFAULT_SIGN_IDENTITY="PromptWise Local Code Signing"
DEFAULT_SIGN_KEYCHAIN="$HOME/Library/Keychains/promptwise-signing.keychain-db"
DEFAULT_SIGN_KEYCHAIN_PASSWORD="promptwise-keychain-pass"

SKIP_BUILD=false
NO_SIGN=false
for arg in "$@"; do
    [[ "$arg" == "--skip-build" ]] && SKIP_BUILD=true
    [[ "$arg" == "--no-sign" ]] && NO_SIGN=true
done

# ─── 编译 ─────────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
    log_step "编译 ${APP_NAME}..."
    swift build -c release
    log_ok "编译完成"
else
    log_warn "已跳过编译（--skip-build）"
fi

BINARY="${BUILD_DIR}/release/${APP_NAME}"
if [[ ! -f "$BINARY" ]]; then
    log_error "找不到编译产物：${BINARY}"
    log_error "请先运行 swift build -c release"
    exit 1
fi

# ─── 创建 .app 包 ─────────────────────────────────────────────────────
log_step "创建 App Bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# 图标处理
ICON_KEY=""
if [[ -f "${ICON_FILE}" ]]; then
    cp "${ICON_FILE}" "${APP_BUNDLE}/Contents/Resources/${ICON_FILE}"
    ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
    log_ok "嵌入图标：${ICON_FILE}"
else
    log_warn "未找到 ${ICON_FILE}，跳过图标（运行 ./create_icon.sh 可生成）"
fi

# Info.plist（与 build_dmg.sh 保持一致）
printf '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>%s</string>
    <key>CFBundleDisplayName</key>
    <string>%s</string>
    <key>CFBundleIdentifier</key>
    <string>com.promptwise.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>%s</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    %s
</dict>
</plist>
' "${APP_NAME}" "${APP_NAME}" "${APP_NAME}" "${ICON_KEY}" \
    > "${APP_BUNDLE}/Contents/Info.plist"

log_ok "App Bundle 创建完成：${APP_BUNDLE}"

# ─── 代码签名（默认启用，避免辅助功能权限反复重授权） ───────────────
if [[ "$NO_SIGN" == true ]]; then
    log_warn "已跳过签名（--no-sign）。该包可能导致重装后需要重新授权辅助功能"
else
    SIGN_IDENTITY="${SIGN_IDENTITY:-$DEFAULT_SIGN_IDENTITY}"
    SIGN_KEYCHAIN="${SIGN_KEYCHAIN:-$DEFAULT_SIGN_KEYCHAIN}"
    SIGN_KEYCHAIN_PASSWORD="${SIGN_KEYCHAIN_PASSWORD:-$DEFAULT_SIGN_KEYCHAIN_PASSWORD}"
    SIGN_HASH="$(security find-identity -p codesigning "$SIGN_KEYCHAIN" | awk -v id="$SIGN_IDENTITY" '$0 ~ "\"" id "\"" {print $2; exit}')"
    if [[ -z "$SIGN_HASH" ]]; then
        log_error "未找到签名身份：${SIGN_IDENTITY}"
        log_error "请先运行 ./create_local_codesign_cert.sh（无需开发者账号）"
        exit 1
    fi

    log_step "使用签名身份进行签名：${SIGN_IDENTITY}"
    ORIGINAL_KEYCHAINS=$(security list-keychains -d user | tr -d '"')
    security list-keychains -d user -s "$SIGN_KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db" >/dev/null
    security unlock-keychain -p "$SIGN_KEYCHAIN_PASSWORD" "$SIGN_KEYCHAIN" >/dev/null || true
    codesign --force --deep --timestamp=none --sign "$SIGN_HASH" "${APP_BUNDLE}"
    security list-keychains -d user -s $ORIGINAL_KEYCHAINS >/dev/null 2>&1 || true
    codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
    log_ok "签名完成并验证通过"
fi

log_step "启动应用：${APP_BUNDLE}"
open "${APP_BUNDLE}"
log_ok "应用已启动"

echo ""
echo -e "${GREEN}${BOLD}完成！${RESET}"
echo ""
echo -e "  .app 路径 : ${BOLD}${APP_BUNDLE}${RESET}"
echo ""
echo -e "${BOLD}快捷操作：${RESET}"
echo -e "  打开测试  →  ${CYAN}open ${APP_BUNDLE}${RESET}"
echo -e "  安装到    →  ${CYAN}cp -r ${APP_BUNDLE} /Applications/${RESET}"
echo ""
