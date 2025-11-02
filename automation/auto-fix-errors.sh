#!/bin/bash
#
# Auto-Fix Errors Script
#
# Automatically fixes common translation errors
# Called by auto-retranslate.sh when validation fails
#
# Returns:
#   0 - Errors fixed successfully
#   1 - Cannot auto-fix (manual intervention required)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
TARGET_FILE="$WORKING_DIR/translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
SOURCE_FILE="$WORKING_DIR/translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
REFERENCE_FILE="$WORKING_DIR/translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt"

LOG_FILE="${1:-/dev/stdout}"

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Check if validation passed
validate_all() {
    local validation_passed=true

    # Structure validation
    if ! python3 "$WORKING_DIR/translation/validate_structure_v2.py" \
        "$TARGET_FILE" \
        --source "$SOURCE_FILE" \
        --detailed > /tmp/structure_validation.log 2>&1; then
        validation_passed=false
    fi

    # Quality validation
    CURRENT_LINE=$(jq -r '.files.base_game.current_line // 390' "$WORKING_DIR/translation/.retranslation_progress.json" 2>/dev/null || echo "390")
    if ! python3 "$WORKING_DIR/translation/validate_translation_quality.py" \
        "$TARGET_FILE" \
        --reference "$REFERENCE_FILE" \
        --start-line 390 \
        --end-line "$CURRENT_LINE" > /tmp/quality_validation.log 2>&1; then
        validation_passed=false
    fi

    if $validation_passed; then
        return 0
    else
        return 1
    fi
}

# Fix action markers translated to Japanese
fix_action_markers() {
    log "INFO" "🔧 Fixing action markers translated to Japanese..."

    # Use Python script for accurate fixing
    if python3 "$WORKING_DIR/automation/auto-fix-action-markers.py" \
        "$TARGET_FILE" \
        "$SOURCE_FILE" 2>&1 | while read -r line; do
            log "INFO" "  $line"
        done; then
        log "INFO" "  ✓ Action markers fixed successfully"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then
            log "INFO" "  → No action marker errors found"
            return 0
        else
            log "ERROR" "  ✗ Action marker fix failed"
            return 1
        fi
    fi
}

# Fix structure errors (quote count mismatch, etc.)
fix_structure_errors() {
    log "INFO" "🔧 Analyzing structure errors..."

    # Run structure validation and capture output
    if python3 "$WORKING_DIR/translation/validate_structure_v2.py" \
        "$TARGET_FILE" \
        --source "$SOURCE_FILE" \
        --detailed > /tmp/structure_errors.log 2>&1; then
        log "INFO" "  → No structure errors found"
        return 0
    fi

    # Parse errors from validation output
    local error_count=$(grep -c "ERROR" /tmp/structure_errors.log || true)

    if [ "$error_count" -eq 0 ]; then
        log "INFO" "  → No fixable structure errors"
        return 0
    fi

    log "WARN" "  → Found $error_count structure error(s)"
    log "WARN" "  → Structure errors require manual review (auto-fix not implemented)"

    # Show first 20 errors for debugging
    log "INFO" "  → First errors:"
    head -20 /tmp/structure_errors.log | while read -r line; do
        log "INFO" "    $line"
    done

    return 1
}

# Main auto-fix routine
main() {
    log "INFO" "========================================="
    log "INFO" "Auto-Fix Errors: Starting"
    log "INFO" "========================================="

    # Check if validation already passes
    if validate_all; then
        log "INFO" "✅ No errors detected - validation passed"
        return 0
    fi

    log "INFO" "⚠ Validation failed - attempting auto-fix"

    # Create timestamped backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local full_backup="${TARGET_FILE}.backup_${timestamp}"
    cp "$TARGET_FILE" "$full_backup"
    log "INFO" "📦 Full backup created: $full_backup"

    # Attempt fixes
    local fixes_applied=false

    # Fix 1: Action markers
    if fix_action_markers; then
        fixes_applied=true
    fi

    # Fix 2: Structure errors (currently limited)
    # fix_structure_errors  # Commented out - needs more robust implementation

    # Re-validate after fixes
    log "INFO" "🔍 Re-validating after fixes..."

    if validate_all; then
        log "INFO" "========================================="
        log "INFO" "✅ Auto-fix SUCCESSFUL"
        log "INFO" "========================================="
        log "INFO" "All errors have been automatically fixed"
        log "INFO" "Backup preserved: $full_backup"

        # Save validation logs
        cat /tmp/structure_validation.log >> "$LOG_FILE" 2>&1 || true
        cat /tmp/quality_validation.log >> "$LOG_FILE" 2>&1 || true

        return 0
    else
        log "ERROR" "========================================="
        log "ERROR" "❌ Auto-fix FAILED"
        log "ERROR" "========================================="
        log "ERROR" "Some errors could not be automatically fixed"
        log "ERROR" "Manual intervention required"
        log "ERROR" ""
        log "ERROR" "Structure validation output:"
        cat /tmp/structure_validation.log | while read -r line; do
            log "ERROR" "  $line"
        done
        log "ERROR" ""
        log "ERROR" "Quality validation output:"
        cat /tmp/quality_validation.log | while read -r line; do
            log "ERROR" "  $line"
        done
        log "ERROR" ""
        log "ERROR" "Backup preserved: $full_backup"

        return 1
    fi
}

# Run main function
main "$@"
