#!/bin/bash
# ==============================================================================
# Safe Terraform Apply Wrapper (Gated by OSI Security Audit & Conftest OPA)
# ==============================================================================
# Usage:
#   ./scripts/tf_safe_apply.sh <directory_with_tf_files> [terraform_options]
# ==============================================================================

set -euo pipefail

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TF_DIR="${1:-.}"
shift || true
EXTRA_ARGS=("$@")

if [ ! -d "$TF_DIR" ]; then
    echo -e "${RED}[Error] Directory '$TF_DIR' does not exist.${NC}"
    exit 1
fi

TF_DIR_ABS="$(cd "$TF_DIR" && pwd)"
echo -e "${BOLD}${YELLOW}=== Safe Terraform Apply: Security Verification & Gating ===${NC}"
echo -e "Target Directory: $TF_DIR_ABS"

# 1. Pre-execution static security gate
echo -e "\n${BOLD}Step 1: Running Static Security Gate Checks...${NC}"
if ! "$SCRIPT_DIR/pre_apply_gate.sh" "$TF_DIR_ABS"; then
    echo -e "\n${BOLD}${RED}🛑 Execution Halted! Pre-execution security check failed.${NC}"
    echo -e "${RED}Resolve all high-severity findings before running terraform apply.${NC}"
    exit 1
fi

# 2. Plan generation & OPA plan validation (if terraform is installed)
if command -v terraform &> /dev/null; then
    echo -e "\n${BOLD}Step 2: Generating Terraform Plan...${NC}"
    PLAN_FILE="$TF_DIR_ABS/tfplan.binary"
    PLAN_JSON="$TF_DIR_ABS/tfplan.json"

    (
        cd "$TF_DIR_ABS"
        terraform plan -out="$PLAN_FILE" "${EXTRA_ARGS[@]}"
        terraform show -json "$PLAN_FILE" > "$PLAN_JSON"
    )

    echo -e "\n${BOLD}Step 3: Running OPA Conftest Plan Verification...${NC}"
    if ! "$SCRIPT_DIR/pre_apply_gate.sh" "$TF_DIR_ABS" "$PLAN_JSON"; then
        echo -e "\n${BOLD}${RED}🛑 Execution Halted! Terraform plan failed OPA policy gate.${NC}"
        rm -f "$PLAN_FILE" "$PLAN_JSON"
        exit 1
    fi

    # 4. Proceed with Apply
    echo -e "\n${BOLD}${GREEN}✅ All gates passed. Applying Terraform Plan...${NC}"
    (
        cd "$TF_DIR_ABS"
        terraform apply "$PLAN_FILE"
    )
    rm -f "$PLAN_FILE" "$PLAN_JSON"
    echo -e "\n${BOLD}${GREEN}Terraform apply completed successfully!${NC}"
else
    echo -e "${YELLOW}[Notice] 'terraform' binary not detected in PATH. Static gate validation passed.${NC}"
fi
