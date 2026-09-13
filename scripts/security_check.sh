#!/bin/bash
set -e

# 色の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# スクリプトの絶対パスからプロジェクトルートを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
POLICY_DIR="$PROJECT_ROOT/policy"

echo -e "${YELLOW}=== Terraform Security Check Tool ===${NC}"
echo -e "Project Root: $PROJECT_ROOT"

# 1. Trivy による包括的スキャン (標準ルール + カスタム Rego ポリシー)
echo -e "\n[1/3] Running Trivy Comprehensive Scan..."
if command -v trivy &> /dev/null; then
    # 非推奨の --policy の代わりに --config-check を使用
    # --config-data で Rego ファイルのパスを指定
    trivy config "$PROJECT_ROOT" \
        --config-check "$POLICY_DIR" \
        --severity HIGH,CRITICAL \
        --exit-code 0
else
    echo -e "\n${RED}[Error] Trivy is not installed.${NC}"
    exit 1
fi

# 2. 機密情報のスキャン (grepによる簡易チェック)
echo -e "\n[2/3] Checking for plain-text secrets..."
secrets_found=$(grep -rE "password|secret|token|key" "$PROJECT_ROOT" \
    --exclude-dir={.git,.terraform,policy,scripts,tests} \
    --exclude="*.md" \
    | grep "=" || true)

if [ -n "$secrets_found" ]; then
    echo -e "${RED}Potential secrets found in plain text:${NC}"
    echo "$secrets_found"
else
    echo -e "${GREEN}No obvious secrets found in plain text.${NC}"
fi

# 3. OSI 参照モデルに基づくセキュリティ設定監査 & Mermaid 関係図生成
echo -e "\n[3/3] Running OSI Reference Model Security Audit & Mermaid Topology Generator..."
if command -v python3 &> /dev/null; then
    python3 "$SCRIPT_DIR/osi_security_audit.py" --target-dir "$PROJECT_ROOT"
else
    echo -e "${YELLOW}[Warning] python3 is not installed. Skipping OSI audit.${NC}"
fi

echo -e "\n${GREEN}Security check completed!${NC}"
