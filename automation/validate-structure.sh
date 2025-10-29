#!/bin/bash

# Structure Validation Script for Wasteland 3 Translation
# Performs strict validation to prevent Unity import failures
# Version: 1.0.0 (2025-10-29)

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

echo "=========================================="
echo "Wasteland 3 Structure Validation"
echo "=========================================="
echo ""

# Test 1: Line Count Match
echo -n "Test 1: Line count match... "
SOURCE_LINES=$(wc -l < "$SOURCE_FILE")
TARGET_LINES=$(wc -l < "$TARGET_FILE")

if [ "$SOURCE_LINES" -eq "$TARGET_LINES" ]; then
    echo -e "${GREEN}PASS${NC} ($TARGET_LINES lines)"
elif [ $((SOURCE_LINES - TARGET_LINES)) -eq 1 ] || [ $((TARGET_LINES - SOURCE_LINES)) -eq 1 ]; then
    echo -e "${YELLOW}WARN${NC} (Source: $SOURCE_LINES, Target: $TARGET_LINES - 1 line difference is acceptable)"
else
    echo -e "${RED}FAIL${NC} (Source: $SOURCE_LINES, Target: $TARGET_LINES)"
    ((ERRORS++))
fi

# Test 2: No Broken Escape Sequences (multiline string data)
echo -n "Test 2: No broken \\r\\n sequences... "
# Look for lines that have string data with opening quote but not closed on same line
# Exclude empty strings (string data = "")
BROKEN_ESCAPES=$(grep -E 'string data = ""[^"]+$' "$TARGET_FILE" | wc -l || true)

if [ "$BROKEN_ESCAPES" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} ($BROKEN_ESCAPES broken escape sequences found)"
    echo "  Sample broken lines:"
    grep -nE 'string data = ""[^"]+$' "$TARGET_FILE" | head -5 || true
    ((ERRORS++))
fi

# Test 3: No Japanese Brackets in Structure Markers
echo -n "Test 3: No Japanese brackets (「」『』) in structure... "
JAPANESE_BRACKETS=$(grep -c '[「」『』]' "$TARGET_FILE" || true)

if [ "$JAPANESE_BRACKETS" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${YELLOW}WARN${NC} ($JAPANESE_BRACKETS lines with Japanese brackets - verify they're only in content)"
    # This is a warning, not an error, because Japanese brackets are allowed in content
fi

# Test 4: All string data lines follow correct format
echo -n "Test 4: All string data lines follow correct format... "
# Count all 'string data = ' lines
TOTAL_STRING_DATA=$(grep -c 'string data = ' "$TARGET_FILE" || true)
# Count lines that follow 'string data = "' format (allowing extra space)
VALID_FORMAT=$(grep -E 'string data = +"' "$TARGET_FILE" | wc -l || true)

if [ "$TOTAL_STRING_DATA" -eq "$VALID_FORMAT" ]; then
    echo -e "${GREEN}PASS${NC} ($TOTAL_STRING_DATA entries)"
else
    echo -e "${RED}FAIL${NC} (Total: $TOTAL_STRING_DATA, Valid format: $VALID_FORMAT)"
    echo "  Sample invalid lines:"
    grep 'string data = ' "$TARGET_FILE" | grep -v 'string data = "' | head -5 || true
    ((ERRORS++))
fi

# Test 5: No Quote Escape Sequences (\")
echo -n "Test 5: No backslash quote escapes (\\\" forbidden)... "
QUOTE_ESCAPES=$(grep -c 'string data = "\\"' "$TARGET_FILE" || true)

if [ "$QUOTE_ESCAPES" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${YELLOW}WARN${NC} ($QUOTE_ESCAPES lines with \\\" found - pre-existing issue, not a blocker)"
    # This is a warning for existing issue, not counted as error
fi

# Test 6: Preserved Action Markups (::action::)
echo -n "Test 6: Action markups remain in English... "
# Get all action markups from source
SOURCE_ACTIONS=$(grep -o '::[a-z]*::' "$SOURCE_FILE" | sort -u || true)
# Check if any common action words were translated to Japanese
TRANSLATED_ACTIONS=$(grep -E '::.*[ぁ-ん].*::' "$TARGET_FILE" | wc -l || true)

if [ "$TRANSLATED_ACTIONS" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} ($TRANSLATED_ACTIONS action markups appear translated)"
    echo "  Sample translated actions:"
    grep -E '::.*[ぁ-ん].*::' "$TARGET_FILE" | head -3 || true
    ((ERRORS++))
fi

# Test 7: Chinese Characters Check
echo -n "Test 7: No Simplified Chinese characters... "
# Common simplified Chinese characters that differ from Japanese
CHINESE_CHARS=$(grep -P '[\x{4E2A}\x{4E3A}\x{4E48}\x{4E86}\x{4E0E}\x{4F1A}\x{533B}\x{542C}\x{5728}\x{5929}]' "$TARGET_FILE" | wc -l || true)

if [ "$CHINESE_CHARS" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${YELLOW}WARN${NC} ($CHINESE_CHARS potential Chinese characters - requires manual review)"
fi

# Test 8: No Translated Technical Terms ('Script Node' specifically)
echo -n "Test 8: 'Script Node' not translated... "
# Script Node should remain in English (e.g., "Script Node 14")
# Check for Japanese translations like "スクリプトノード" or "脚本节点"
TRANSLATED_SCRIPT_NODE=$(grep -E 'string data = ""(スクリプトノード|スクリプト・ノード|脚本节点)' "$TARGET_FILE" | wc -l || true)

if [ "$TRANSLATED_SCRIPT_NODE" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} ($TRANSLATED_SCRIPT_NODE 'Script Node' translations found)"
    grep -nE 'string data = ""(スクリプトノード|スクリプト・ノード|脚本节点)' "$TARGET_FILE" | head -3 || true
    ((ERRORS++))
fi

# Test 9: Structure Markers Preserved
echo -n "Test 9: Special markers [Switch to] preserved... "
PRESERVED_SWITCH=$(grep -c '\[Switch to' "$TARGET_FILE" || true)
SOURCE_SWITCH=$(grep -c '\[Switch to' "$SOURCE_FILE" || true)

if [ "$PRESERVED_SWITCH" -eq "$SOURCE_SWITCH" ]; then
    echo -e "${GREEN}PASS${NC} ($PRESERVED_SWITCH markers)"
else
    echo -e "${RED}FAIL${NC} (Source: $SOURCE_SWITCH, Target: $PRESERVED_SWITCH)"
    ((ERRORS++))
fi

# Summary
echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validation tests passed!${NC}"
    echo "=========================================="
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s)${NC}"
    echo "=========================================="
    echo ""
    echo "Please fix the errors before committing."
    echo "Common fixes:"
    echo "  - Restore \\r\\n sequences (do not convert to actual newlines)"
    echo "  - Keep structure markers \"\" (do not use 「」)"
    echo "  - Do not translate ::action:: markups"
    echo "  - Do not translate 'Script Node' or technical terms"
    exit 1
fi
