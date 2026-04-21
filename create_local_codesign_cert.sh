#!/bin/bash
# 创建本地可复用的代码签名证书（无需 Apple 开发者账号）
# 用法：
#   ./create_local_codesign_cert.sh
#   CERT_NAME="PromptWise Local Code Signing" ./create_local_codesign_cert.sh

set -euo pipefail

CERT_NAME="${CERT_NAME:-PromptWise Local Code Signing}"
KEYCHAIN="${KEYCHAIN:-$HOME/Library/Keychains/promptwise-signing.keychain-db}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-promptwise-keychain-pass}"
DAYS="${DAYS:-3650}"
P12_PASS="${P12_PASS:-promptwise-local-sign-pass}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

KEY_FILE="$TMP_DIR/key.pem"
CERT_FILE="$TMP_DIR/cert.pem"
P12_FILE="$TMP_DIR/cert.p12"
OPENSSL_CFG="$TMP_DIR/openssl.cnf"

cat > "$OPENSSL_CFG" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3_codesign
prompt = no

[dn]
CN = ${CERT_NAME}
O = PromptWise Local

[v3_codesign]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

echo "▶ 生成自签名证书：${CERT_NAME}"
openssl req -new -newkey rsa:2048 -nodes \
  -keyout "$KEY_FILE" \
  -x509 -days "$DAYS" \
  -out "$CERT_FILE" \
  -config "$OPENSSL_CFG" >/dev/null 2>&1

openssl pkcs12 -export \
  -inkey "$KEY_FILE" \
  -in "$CERT_FILE" \
  -name "$CERT_NAME" \
  -out "$P12_FILE" \
  -passout pass:"$P12_PASS" >/dev/null 2>&1

if [[ ! -f "$KEYCHAIN" ]]; then
  echo "▶ 创建专用 keychain：${KEYCHAIN}"
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
fi

echo "▶ 解锁 keychain：${KEYCHAIN}"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security set-keychain-settings -lut 21600 "$KEYCHAIN" >/dev/null

echo "▶ 导入证书与私钥到 Keychain：${KEYCHAIN}"
if ! security import "$P12_FILE" -k "$KEYCHAIN" -P "$P12_PASS" -A >/dev/null 2>&1; then
  echo "⚠ 首次导入失败，尝试 legacy 格式重新导出..."
  openssl pkcs12 -export -legacy \
    -inkey "$KEY_FILE" \
    -in "$CERT_FILE" \
    -name "$CERT_NAME" \
    -out "$P12_FILE" \
    -passout pass:"$P12_PASS" >/dev/null 2>&1

  security import "$P12_FILE" -k "$KEYCHAIN" -P "$P12_PASS" -A >/dev/null
fi

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null || true

echo "✔ 完成。当前可用 codesign 身份："
security find-identity -v -p codesigning "$KEYCHAIN" | sed 's/^/  /'

echo ""
echo "下一步：运行 ./build_dmg.sh（默认会优先使用 \"${CERT_NAME}\" 签名）"
