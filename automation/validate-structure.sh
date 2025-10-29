#!/bin/bash

# Structure Validation Script for Wasteland 3 Translation
# Wrapper for validate_structure_v2.py with additional quick checks
# Version: 2.0.0 (2025-10-29)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SOURCE_FILE="translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
TARGET_FILE="translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"

ERRORS=0

# Primary validation: Use validate_structure_v2.py (most accurate)
echo "=========================================="
echo "Primary Validation (validate_structure_v2.py)"
echo "=========================================="
if python3 translation/validate_structure_v2.py "$TARGET_FILE" --source "$SOURCE_FILE" 2>&1 | grep -q "エラー: 0件"; then
    echo -e "${GREEN}✓ Structure validation PASSED${NC}"
else
    echo -e "${RED}✗ Structure validation FAILED${NC}"
    echo "Running detailed validation..."
    python3 translation/validate_structure_v2.py "$TARGET_FILE" --source "$SOURCE_FILE" --detailed
    exit 1
fi

echo "=========================================="
echo "Secondary Quick Checks (Supplementary)"
echo "=========================================="

# Quick check for Japanese brackets (warning only)
echo -n "Quick check: Japanese brackets... "
JAPANESE_BRACKETS=$(grep -c '[「」『』]' "$TARGET_FILE" || true)
if [ "$JAPANESE_BRACKETS" -eq 0 ]; then
    echo -e "${GREEN}OK${NC} (none found)"
else
    echo -e "${YELLOW}INFO${NC} ($JAPANESE_BRACKETS lines - may be in translated content)"
fi

# Quick check for Chinese characters (warning only)
echo -n "Quick check: Simplified Chinese chars... "
CHINESE_CHARS=$(grep -P '[\x{4E2A}\x{4E3A}\x{4E48}\x{4E86}\x{4E0E}\x{4F1A}\x{533B}\x{542C}\x{5728}\x{5929}]' "$TARGET_FILE" 2>/dev/null | wc -l || echo "0")
if [ "$CHINESE_CHARS" -eq 0 ]; then
    echo -e "${GREEN}OK${NC} (none found)"
else
    echo -e "${YELLOW}INFO${NC} ($CHINESE_CHARS potential matches - review recommended)"
fi

# Summary
echo ""
echo "=========================================="
echo -e "${GREEN}✓ All validation checks passed!${NC}"
echo "=========================================="
exit 0
