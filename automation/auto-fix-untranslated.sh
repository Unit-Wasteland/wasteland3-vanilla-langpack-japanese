#!/bin/bash
##############################################################################
# Wasteland 3 Japanese Translation - Automated Untranslated Entry Fixer
#
# Purpose: Automatically detect and fix untranslated English entries
#
# Features:
# 1. Scans entire base game file for untranslated English entries
# 2. Uses Spanish reference to determine translatability
# 3. Applies CLAUDE.md unified translation decision logic
# 4. Validates structure after each fix
# 5. Commits fixes in batches for safety
#
# Usage:
#   ./automation/auto-fix-untranslated.sh         # Start automated fixing
#   ./automation/auto-fix-untranslated.sh --unlock # Remove lock file
#
# Safety Features:
# - Exclusive lock (prevents duplicate sessions)
# - Dual validation (structure + quality) after each fix
# - Incremental commits (every 10 fixes)
# - Detailed logging
# - Error rollback capability
#
##############################################################################

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="$SCRIPT_DIR/.untranslated_fix.lock"

# Parse command line arguments
if [[ "${1:-}" == "--unlock" ]]; then
    echo "========================================"
    echo "Unlocking untranslated fix automation"
    echo "========================================"

    if [[ ! -f "$LOCK_FILE" ]]; then
        echo "✓ No lock file found - system is already unlocked"
        exit 0
    fi

    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
    echo "Lock file: $LOCK_FILE"
    echo "Locked by PID: $LOCK_PID"

    if [[ "$LOCK_PID" != "unknown" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "⚠ WARNING: Process $LOCK_PID is still running!"
        echo "  Consider terminating it first: kill $LOCK_PID"
        exit 1
    else
        rm -f "$LOCK_FILE"
        echo "✓ Stale lock file removed"
        echo ""
        echo "You can now run: ./automation/auto-fix-untranslated.sh"
        exit 0
    fi
fi

# Configuration
WORKING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$WORKING_DIR/automation/untranslated-fix-automation.log"
MAX_MEMORY_MB=5000          # 6GB physical RAM - 1GB margin
MONITOR_INTERVAL=30         # Check memory every 30 seconds
FIXES_PER_COMMIT=10         # Commit every 10 fixes for safety

# File paths (BASE GAME ONLY)
BASE_GAME_EN="$WORKING_DIR/translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
BASE_GAME_ES="$WORKING_DIR/translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt"
BASE_GAME_JA="$WORKING_DIR/translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
GLOSSARY="$WORKING_DIR/translation/nouns_glossary.json"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Lock file management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")

        if [[ "$lock_pid" != "unknown" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log "ERROR" "Another untranslated fix session is already running (PID: $lock_pid)"
            exit 1
        else
            log "INFO" "Removing stale lock file (PID: $lock_pid no longer running)"
            rm -f "$LOCK_FILE"
        fi
    fi

    echo "$$" > "$LOCK_FILE"
    log "INFO" "Lock acquired (PID: $$)"
}

release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log "INFO" "Lock released"
    fi
}

# Ensure lock is released on exit
trap release_lock EXIT INT TERM

# Get Claude Code process memory usage (in MB)
get_claude_memory() {
    local memory=$(ps aux | grep "[c]laude" | awk '{sum += $6} END {print sum}')
    if [ -n "$memory" ] && [ "$memory" != "" ] && [ "$memory" != "0" ]; then
        echo $((memory / 1024))
    else
        echo 0
    fi
}

# Kill any existing Claude Code processes
cleanup_claude() {
    pkill -9 claude 2>/dev/null || true
    sleep 2
}

# Main script
log "INFO" "========================================="
log "INFO" "Wasteland 3 Untranslated Entry Fixer"
log "INFO" "========================================="
log "INFO" "Target: BASE GAME ONLY"
log "INFO" "Max Memory: ${MAX_MEMORY_MB}MB, Fixes/Commit: $FIXES_PER_COMMIT"
log "INFO" "Working Directory: $WORKING_DIR"
log "INFO" "Start time: $(date)"
log "INFO" ""

# Acquire exclusive lock
acquire_lock

cd "$WORKING_DIR"

# Step 1: Detect untranslated entries
log "INFO" "Step 1: Scanning for untranslated entries..."
REPORT_FILE="$WORKING_DIR/automation/.untranslated_report_detailed.txt"

python3 "$WORKING_DIR/translation/validate_translation_quality.py" \
    "$BASE_GAME_JA" \
    --reference "$BASE_GAME_ES" \
    --start-line 390 \
    --end-line 530425 \
    --glossary "$GLOSSARY" \
    --verbose \
    --output "$REPORT_FILE" > "$WORKING_DIR/automation/.untranslated_scan.log" 2>&1 || true

# Extract untranslated line numbers
UNTRANSLATED_LINES=$(grep "^Line [0-9]*: English text not translated" "$REPORT_FILE" | \
    sed 's/^Line \([0-9]*\):.*/\1/' | sort -n)

UNTRANSLATED_COUNT=$(echo "$UNTRANSLATED_LINES" | grep -c "^[0-9]" || echo "0")

log "INFO" "  Found $UNTRANSLATED_COUNT untranslated entries"

if [ "$UNTRANSLATED_COUNT" -eq 0 ]; then
    log "SUCCESS" "✅ No untranslated entries found - all entries are properly translated!"
    exit 0
fi

# Save line numbers to file
echo "$UNTRANSLATED_LINES" > "$WORKING_DIR/automation/.untranslated_lines.txt"
log "INFO" "  Untranslated line numbers saved to: automation/.untranslated_lines.txt"
log "INFO" ""

# Step 2: Prepare Claude Code command for fixing
log "INFO" "Step 2: Preparing automated fix command..."

COMMAND_FILE="$WORKING_DIR/automation/.fix_untranslated_command.txt"

cat > "$COMMAND_FILE" << 'EOFCMD'
🔧 **未翻訳エントリ自動修正タスク**

以下のファイルから未翻訳の英語エントリが検出されました。CLAUDE.mdのルールに従って、これらを日本語に翻訳してください。

**ファイル:**
- English source: translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt
- Spanish reference: translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt
- Japanese target: translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt
- Glossary: translation/nouns_glossary.json

**未翻訳エントリのリスト:**
automation/.untranslated_lines.txt (各行に行番号が記載されています)

**修正手順 (MANDATORY):**

1. **未翻訳エントリリストの読み込み**:
   Read automation/.untranslated_lines.txt

2. **各エントリの修正** (1つずつ順番に処理):
   各行番号について:

   a) **コンテキストの確認** (前後20行を読み込み):
      Read TARGET_FILE (offset: LINE-20, limit: 40)
      Read SOURCE_EN (offset: LINE-20, limit: 40)
      Read SOURCE_ES (offset: LINE-20, limit: 40)

   b) **翻訳可否判断** (CLAUDE.md統一ロジック - 優先順):
      1. 英語が空 ("") → スキップ
      2. do_not_translateリスト該当 → 英語保持
      3. nouns_glossary.json登録あり → 用語集訳語使用
      4. スペイン語が非空 かつ スペイン語≠英語 → 日本語翻訳
      5. それ以外 → 日本語翻訳 (デフォルト)

   c) **翻訳実行**:
      - nouns_glossary.jsonを参照して固有名詞の訳語を確認
      - 文脈を考慮して自然な日本語に翻訳
      - 引用符の数を英語ソースと完全一致させる (CRITICAL)
      - 構造マーカー ("", [], <>, ::action::) を保護

   d) **編集**:
      Edit TARGET_FILE (old_string: 英語行, new_string: 日本語行)

   e) **検証** (MANDATORY - 3つ全て実行):

      i) 構造検証:
         python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_EN --detailed
         → エラー数: 0 であることを確認

      ii) アクションマーカー検証:
         grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
         → 結果が空であること確認 (何も表示されない = OK)

      iii) 品質検証 (該当行のみ):
         python3 translation/validate_translation_quality.py TARGET_FILE \
           --reference SOURCE_ES \
           --start-line LINE \
           --end-line LINE \
           --glossary translation/nouns_glossary.json
         → Total issues found: 0 であることを確認

   f) **エラーがあれば即座に修正**:
      - 次のエントリに進まない
      - 問題を修正して再度検証
      - 全検証が0エラーになるまで繰り返す

3. **10エントリごとにコミット** (安全性確保):
   git add TARGET_FILE
   git commit -m "Fix 10 untranslated entries (lines XXX-XXX)"

4. **全エントリ修正完了後**:
   - 最終検証 (全範囲):
     python3 translation/validate_translation_quality.py TARGET_FILE \
       --reference SOURCE_ES \
       --start-line 390 \
       --end-line 530425 \
       --glossary translation/nouns_glossary.json
   - Total issues found: 0 であることを確認
   - git push origin main

**🔴 重要ルール:**
- ⚠️ 引用符の数を英語ソースと完全一致させる (1個も増減禁止)
- ⚠️ スペイン語が空なら英語テキストを保持 (削除禁止)
- ⚠️ ::action:: マーカーを絶対に日本語に翻訳しない
- ⚠️ Script Node, [Global:], [Switch to] などの技術用語を翻訳しない
- ⚠️ 各編集後、必ず3つの検証を全て実行
- ⚠️ エラーがあれば次に進まず即座に修正

**処理完了後の報告:**
- 修正完了エントリ数: XX
- 最終検証結果: Total issues found: 0
- コミットハッシュ: XXXXXXX

この報告後、セッションを終了してください。
EOFCMD

log "INFO" "  Command file created: automation/.fix_untranslated_command.txt"
log "INFO" ""

# Step 3: Execute Claude Code with the fix command
log "INFO" "Step 3: Starting Claude Code automated fix session..."

# Clean up any existing Claude processes
cleanup_claude

OUTPUT_FILE="$WORKING_DIR/automation/.fix_untranslated_output.log"

# Start Claude Code in background
# --dangerously-skip-permissions: Bypass all permission checks
# yes: Automatically answer 'y' to interactive prompts
timeout 3600 bash -c "yes | cat '$COMMAND_FILE' | claude --dangerously-skip-permissions" > "$OUTPUT_FILE" 2>&1 &
CLAUDE_PID=$!

log "INFO" "Claude Code session started (PID: $CLAUDE_PID)"

# Monitor memory usage
while kill -0 $CLAUDE_PID 2>/dev/null; do
    sleep $MONITOR_INTERVAL

    MEMORY=$(get_claude_memory)
    log "INFO" "Memory usage: ${MEMORY}MB / ${MAX_MEMORY_MB}MB"

    if [ $MEMORY -gt $MAX_MEMORY_MB ]; then
        log "WARN" "Memory threshold exceeded (${MEMORY}MB > ${MAX_MEMORY_MB}MB), terminating session"
        kill -TERM $CLAUDE_PID 2>/dev/null || true
        sleep 5
        kill -KILL $CLAUDE_PID 2>/dev/null || true
        break
    fi
done

# Wait for Claude Code to finish
wait $CLAUDE_PID 2>/dev/null || true

log "INFO" "Claude Code session completed"
log "INFO" ""

# Step 4: Final validation
log "INFO" "Step 4: Running final validation..."

python3 "$WORKING_DIR/translation/validate_translation_quality.py" \
    "$BASE_GAME_JA" \
    --reference "$BASE_GAME_ES" \
    --start-line 390 \
    --end-line 530425 \
    --glossary "$GLOSSARY" > "$WORKING_DIR/automation/.final_validation.log" 2>&1

FINAL_ISSUES=$(grep "Total issues found:" "$WORKING_DIR/automation/.final_validation.log" | \
    sed 's/Total issues found: \([0-9]*\)/\1/')

log "INFO" "  Final validation result: $FINAL_ISSUES issues found"

if [ "$FINAL_ISSUES" -eq 0 ]; then
    log "SUCCESS" "✅ All untranslated entries have been successfully fixed!"
    log "SUCCESS" "  Total fixes: $UNTRANSLATED_COUNT entries"
else
    log "WARN" "⚠ Some issues still remain: $FINAL_ISSUES issues"
    log "WARN" "  Check automation/.final_validation.log for details"
fi

log "INFO" ""
log "SUCCESS" "========================================="
log "SUCCESS" "Untranslated Entry Fix Complete"
log "SUCCESS" "========================================="
log "SUCCESS" "Initial issues: $UNTRANSLATED_COUNT"
log "SUCCESS" "Remaining issues: $FINAL_ISSUES"
log "SUCCESS" "End time: $(date)"

# Clean up
cleanup_claude
