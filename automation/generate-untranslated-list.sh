#!/bin/bash
##############################################################################
# Generate Untranslated Entries List
#
# Purpose: Scan translation file and generate list of untranslated line numbers
#
# Usage:
#   ./automation/generate-untranslated-list.sh
#
# Output:
#   automation/.untranslated_lines.txt - List of line numbers (one per line)
##############################################################################

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# File paths
TARGET_FILE="$WORKING_DIR/translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
REFERENCE_FILE="$WORKING_DIR/translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt"
GLOSSARY_FILE="$WORKING_DIR/translation/nouns_glossary.json"
OUTPUT_FILE="$WORKING_DIR/automation/.untranslated_lines.txt"
REPORT_FILE="$WORKING_DIR/automation/.untranslated_report.txt"

echo "========================================"
echo "Generating Untranslated Entries List"
echo "========================================"
echo "Target file: $TARGET_FILE"
echo "Reference file: $REFERENCE_FILE"
echo "Glossary file: $GLOSSARY_FILE"
echo ""

# Run validation and capture output
echo "Running validation..."
python3 "$WORKING_DIR/translation/validate_translation_quality.py" \
    "$TARGET_FILE" \
    --reference "$REFERENCE_FILE" \
    --start-line 390 \
    --end-line 999999999 \
    --glossary "$GLOSSARY_FILE" \
    > "$REPORT_FILE" 2>&1 || true

# Extract untranslated line numbers from report
# Look for lines like "  2192, 2410, 2542, ..." after "All untranslated line numbers"
echo "Extracting line numbers..."
awk '
/All untranslated line numbers/ { in_section = 1; next }
/^\[3\]/ { in_section = 0 }
in_section && /^  [0-9]/ {
    gsub(/,/, "\n", $0)
    gsub(/ /, "", $0)
    print $0
}
' "$REPORT_FILE" | grep -E '^[0-9]+$' | sort -n > "$OUTPUT_FILE"

LINE_COUNT=$(wc -l < "$OUTPUT_FILE")

echo ""
echo "========================================"
echo "✓ Untranslated Entries List Generated"
echo "========================================"
echo "Total untranslated entries: $LINE_COUNT"
echo "Output file: $OUTPUT_FILE"
echo "Full report: $REPORT_FILE"
echo ""

if [ $LINE_COUNT -eq 0 ]; then
    echo "✅ No untranslated entries found - translation complete!"
    exit 0
fi

# Show first 20 lines as sample
echo "Sample (first 20 lines):"
head -20 "$OUTPUT_FILE"
echo ""

exit 0
