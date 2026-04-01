#!/bin/bash
# create_icon.sh — 将 1024×1024 PNG 转换为 macOS .icns 图标
#
# 用法：
#   ./create_icon.sh icon_source.png
#   ./create_icon.sh icon_source.png AppIcon.icns   # 指定输出文件名
#
# 依赖：macOS 内置的 sips + iconutil（无需额外安装）

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

# ─── 参数检查 ─────────────────────────────────────────────────────────
SOURCE_PNG="${1}"
OUTPUT_ICNS="${2:-AppIcon.icns}"

if [[ -z "$SOURCE_PNG" ]]; then
    echo ""
    echo -e "${BOLD}用法：${RESET} ./create_icon.sh <source.png> [output.icns]"
    echo ""
    echo "  source.png   输入图片（建议 1024×1024 PNG，透明背景）"
    echo "  output.icns  输出文件名（默认：AppIcon.icns）"
    echo ""
    exit 1
fi

if [[ ! -f "$SOURCE_PNG" ]]; then
    log_error "找不到源文件：${SOURCE_PNG}"
    exit 1
fi

if ! command -v sips &>/dev/null || ! command -v iconutil &>/dev/null; then
    log_error "此脚本需要 macOS 内置的 sips 和 iconutil"
    exit 1
fi

# ─── 工作目录 ─────────────────────────────────────────────────────────
ICONSET_DIR="AppIcon.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

log_step "生成多分辨率图标..."

# macOS 要求的所有尺寸
declare -a SIZES=(16 32 64 128 256 512 1024)

for SIZE in "${SIZES[@]}"; do
    # 1x
    sips -z ${SIZE} ${SIZE} "${SOURCE_PNG}" \
        --out "${ICONSET_DIR}/icon_${SIZE}x${SIZE}.png" \
        > /dev/null 2>&1
    log_ok "  ${SIZE}×${SIZE}"

    # 2x（高分辨率，Retina），1024 不需要 @2x
    if [[ $SIZE -lt 512 ]]; then
        DOUBLE=$((SIZE * 2))
        sips -z ${DOUBLE} ${DOUBLE} "${SOURCE_PNG}" \
            --out "${ICONSET_DIR}/icon_${SIZE}x${SIZE}@2x.png" \
            > /dev/null 2>&1
        log_ok "  ${SIZE}×${SIZE}@2x  →  ${DOUBLE}×${DOUBLE}"
    fi
done

# iconutil 需要特定命名格式（16/32/128/256/512 的 1x + @2x）
# 先整理 iconset 内文件名为 iconutil 标准格式
FINAL_ICONSET="AppIcon_final.iconset"
rm -rf "${FINAL_ICONSET}"
mkdir -p "${FINAL_ICONSET}"

cp "${ICONSET_DIR}/icon_16x16.png"      "${FINAL_ICONSET}/icon_16x16.png"
cp "${ICONSET_DIR}/icon_32x32.png"      "${FINAL_ICONSET}/icon_16x16@2x.png"
cp "${ICONSET_DIR}/icon_32x32.png"      "${FINAL_ICONSET}/icon_32x32.png"
cp "${ICONSET_DIR}/icon_64x64.png"      "${FINAL_ICONSET}/icon_32x32@2x.png"
cp "${ICONSET_DIR}/icon_128x128.png"    "${FINAL_ICONSET}/icon_128x128.png"
cp "${ICONSET_DIR}/icon_256x256.png"    "${FINAL_ICONSET}/icon_128x128@2x.png"
cp "${ICONSET_DIR}/icon_256x256.png"    "${FINAL_ICONSET}/icon_256x256.png"
cp "${ICONSET_DIR}/icon_512x512.png"    "${FINAL_ICONSET}/icon_256x256@2x.png"
cp "${ICONSET_DIR}/icon_512x512.png"    "${FINAL_ICONSET}/icon_512x512.png"
cp "${ICONSET_DIR}/icon_1024x1024.png"  "${FINAL_ICONSET}/icon_512x512@2x.png"

# ─── 转换 .icns ───────────────────────────────────────────────────────
log_step "合成 ${OUTPUT_ICNS}..."
iconutil -c icns "${FINAL_ICONSET}" -o "${OUTPUT_ICNS}"

# 清理临时目录
rm -rf "${ICONSET_DIR}" "${FINAL_ICONSET}"

ICNS_SIZE=$(du -sh "${OUTPUT_ICNS}" | awk '{print $1}')
log_ok "已生成：${OUTPUT_ICNS}（${ICNS_SIZE}）"

echo ""
echo -e "${GREEN}${BOLD}完成！${RESET}"
echo ""
echo -e "  .icns 文件 : ${BOLD}${OUTPUT_ICNS}${RESET}"
echo ""
echo -e "${BOLD}下一步：${RESET}"
echo -e "  运行  ${CYAN}./build_dmg.sh${RESET}  即可自动将图标打入 App Bundle"
echo ""
