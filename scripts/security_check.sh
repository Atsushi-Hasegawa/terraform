#!/bin/bash
set -e

# 色の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Terraform Security Check Tool ===${NC}"

# 1. Trivy による包括的スキャン (標準ルール + カスタム Rego ポリシー)
echo -e "\n[1/2] Running Trivy Comprehensive Scan..."
if command -v trivy &> /dev/null; then
    # --policy で policy/ ディレクトリの Rego ファイルを読み込む
    # --severity でフィルタリング
    trivy config . \
        --policy policy/ \
        --severity HIGH,CRITICAL \
        --exit-code 0 # CI等で失敗させたい場合は 1 に設定

else
    echo -e "\n${RED}[Error] Trivy is not installed.${NC}"
    exit 1
fi

# 2. 機密情報のスキャン (grepによる簡易チェック)
echo -e "\n[2/2] Checking for plain-text secrets..."
# password, secret, token, key 等を検索 (変数定義の default 値などを重点的に)
# 結果があれば表示し、なければメッセージを表示
secrets_found=$(grep -rE "password|secret|token|key" . \
    --exclude-dir={.git,.terraform,policy,scripts,tests} \
    --exclude="*.md" \
    | grep "=" || true)

if [ -n "$secrets_found" ]; then
    echo -e "${RED}Potential secrets found in plain text:${NC}"
    echo "$secrets_found"
else
    echo -e "${GREEN}No obvious secrets found in plain text.${NC}"
fi

echo -e "\n${GREEN}Security check completed!${NC}"
