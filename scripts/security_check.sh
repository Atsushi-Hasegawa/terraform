#!/bin/bash
# ==============================================================================
# Comprehensive Security Check & OPA Conftest Verification Pipeline
# ==============================================================================

set -euo pipefail

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
POLICY_DIR="$PROJECT_ROOT/policy"
RULES_CONFIG="$SCRIPT_DIR/osi_rules.yaml"

STRICT_MODE=false
for arg in "$@"; do
    if [ "$arg" == "--strict" ] || [ "$arg" == "-s" ]; then
        STRICT_MODE=true
    fi
done

echo -e "${BOLD}${CYAN}==============================================================================${NC}"
echo -e "${BOLD}${CYAN}  Terraform Security Check & Conftest OPA Governance Pipeline${NC}"
echo -e "${BOLD}${CYAN}==============================================================================${NC}"
echo -e "Project Root: $PROJECT_ROOT"
echo -e "Policy Dir  : $POLICY_DIR"
echo -e "Strict Mode : $STRICT_MODE\n"

HAS_FAILURES=false

# 1. Conftest による OPA ポリシー検査
echo -e "${BOLD}[1/4] Running Conftest OPA Policy Verification...${NC}"
if command -v conftest &> /dev/null; then
    if [ -f "$POLICY_DIR/encrypted_resources.json" ]; then
        if conftest test --rego-version v0 --all-namespaces --policy "$POLICY_DIR" "$POLICY_DIR/encrypted_resources.json"; then
            echo -e "${GREEN}✓ Conftest OPA static evaluation passed.${NC}"
        else
            echo -e "${RED}✗ Conftest OPA policy violations detected.${NC}"
            HAS_FAILURES=true
        fi
    fi
else
    echo -e "${YELLOW}[Notice] conftest is not installed. Skipping Conftest OPA check.${NC}"
fi

# 2. Trivy による包括的スキャン (標準ルール + カスタム Rego ポリシー)
echo -e "\n${BOLD}[2/4] Running Trivy Comprehensive Misconfiguration Scan...${NC}"
if command -v trivy &> /dev/null; then
    TRIVY_EXIT=0
    if [ "$STRICT_MODE" = true ]; then
        TRIVY_EXIT=1
    fi
    if ! trivy config "$PROJECT_ROOT" \
        --config-check "$POLICY_DIR" \
        --severity HIGH,CRITICAL \
        --exit-code "$TRIVY_EXIT" \
        --skip-version-check; then
        echo -e "${RED}✗ Trivy detected HIGH/CRITICAL security misconfigurations.${NC}"
        HAS_FAILURES=true
    else
        echo -e "${GREEN}✓ Trivy scan completed clean.${NC}"
    fi
else
    echo -e "${YELLOW}[Warning] Trivy is not installed. Skipping Trivy scan.${NC}"
fi

# 3. 機密情報のスキャン (grepによる簡易チェック)
echo -e "\n${BOLD}[3/4] Checking for plain-text secrets...${NC}"
secrets_found=$(grep -rE "password|secret|token|private_key" "$PROJECT_ROOT" \
    --exclude-dir={.git,.terraform,policy,scripts,tests,.gemini} \
    --exclude="*.md" \
    --exclude="*.bak" \
    --exclude="*.json" \
    | grep -v "var\." \
    | grep -v "manage_master_user_password" \
    | grep -v "http_tokens" \
    | grep -v '\["secrets"\]' \
    | grep -v "true" \
    | grep -v "false" \
    | grep "=" || true)

if [ -n "$secrets_found" ]; then
    echo -e "${RED}✗ Potential plain-text secrets found:${NC}"
    echo "$secrets_found"
    HAS_FAILURES=true
else
    echo -e "${GREEN}✓ No obvious plain-text secrets found.${NC}"
fi

# 4. OSI 参照モデルに基づくセキュリティ設定監査 & Mermaid 関係図生成
echo -e "\n${BOLD}[4/4] Running OSI Reference Model Security Audit & Remediation Analysis...${NC}"
if command -v python3 &> /dev/null; then
    EXTRA_FLAG_STR=""
    if [ "$STRICT_MODE" = true ]; then
        EXTRA_FLAG_STR="--exit-code"
    fi
    if ! python3 "$SCRIPT_DIR/osi_security_audit.py" \
        --target-dir "$PROJECT_ROOT" \
        --rules-config "$RULES_CONFIG" \
        $EXTRA_FLAG_STR; then
        echo -e "${RED}✗ OSI Reference Model audit reported high-severity findings.${NC}"
        HAS_FAILURES=true
    fi
else
    echo -e "${YELLOW}[Warning] python3 is not installed. Skipping OSI audit.${NC}"
fi

echo -e "\n${BOLD}${CYAN}==============================================================================${NC}"
if [ "$HAS_FAILURES" = true ] && [ "$STRICT_MODE" = true ]; then
    echo -e "${BOLD}${RED}Security check failed under strict mode!${NC}"
    exit 1
else
    echo -e "${BOLD}${GREEN}Security check completed!${NC}"
fi
