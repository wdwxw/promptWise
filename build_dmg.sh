#!/bin/bash
# PromptWise - Build Release DMG
# Usage:
#   ./build_dmg.sh              # 使用默认版本 1.0.0
#   ./build_dmg.sh 1.2.0        # 指定版本号
#   ./build_dmg.sh 1.2.0 --skip-build   # 仅打包（跳过 swift build）

set -e

# ─── 颜色 ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_step()  { echo -e "${CYAN}${BOLD}▶ $1${RESET}"; }
log_ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
log_warn()  { echo -e "${YELLOW}⚠ $1${RESET}"; }
log_error() { echo -e "${RED}✘ $1${RESET}" >&2; }

# ─── 参数 ────────────────────────────────────────────────────────────
APP_NAME="PromptWise"
VERSION="${1:-1.0.0}"
SKIP_BUILD=false
for arg in "$@"; do
    [[ "$arg" == "--skip-build" ]] && SKIP_BUILD=true
done

BUILD_DIR=".build"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}"
VOLUME_NAME="${APP_NAME}"
ICON_FILE="AppIcon.icns"   # 如果存在 AppIcon.icns 则自动嵌入

# ─── 环境检查 ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   PromptWise  Build & DMG  v${VERSION}  ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════╝${RESET}"
echo ""

if ! command -v swift &>/dev/null; then
    log_error "未找到 swift，请先安装 Xcode Command Line Tools"
    exit 1
fi
if ! command -v hdiutil &>/dev/null; then
    log_error "未找到 hdiutil（仅支持 macOS）"
    exit 1
fi

# ─── 编译 ─────────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
    log_step "编译 Release 版本..."
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

# Info.plist（使用 printf 以便插入动态变量）
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
    <string>%s</string>
    <key>CFBundleShortVersionString</key>
    <string>%s</string>
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
' "${APP_NAME}" "${APP_NAME}" "${VERSION}" "${VERSION}" "${APP_NAME}" "${ICON_KEY}" \
    > "${APP_BUNDLE}/Contents/Info.plist"

log_ok "App Bundle 创建完成：${APP_BUNDLE}"

# ─── 创建 DMG ─────────────────────────────────────────────────────────
log_step "打包 DMG..."

# 清理旧文件
rm -rf "DMG_Temp"
rm -f "${DMG_NAME}.dmg"

mkdir -p "DMG_Temp"
cp -r "${APP_BUNDLE}" "DMG_Temp/"
ln -sf /Applications "DMG_Temp/Applications"

hdiutil create \
    -volname  "${VOLUME_NAME}" \
    -srcfolder "DMG_Temp" \
    -ov \
    -format   UDZO \
    "${DMG_NAME}.dmg"

rm -rf "DMG_Temp"

DMG_SIZE=$(du -sh "${DMG_NAME}.dmg" | awk '{print $1}')
log_ok "DMG 创建完成：${DMG_NAME}.dmg（${DMG_SIZE}）"

# ─── 完成 ─────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║        打包成功！                 ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════╝${RESET}"
echo ""
echo -e "  DMG 文件 : ${BOLD}${DMG_NAME}.dmg${RESET}"
echo -e "  版本     : ${BOLD}${VERSION}${RESET}"
echo ""
echo -e "${BOLD}安装方法：${RESET}"
echo -e "  1. 双击打开  ${DMG_NAME}.dmg"
echo -e "  2. 将 PromptWise.app 拖入 Applications 文件夹"
echo -e "  3. 在启动台或 Applications 中打开 PromptWise"
echo ""
