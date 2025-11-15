# Untranslated Entry Detection and Auto-Fix Tools

## Overview

These tools automatically detect and fix untranslated English entries in the Wasteland 3 Japanese translation project.

### Discovered Issue (2025-11-15)

Despite the progress tracker showing 100% completion, a comprehensive scan revealed **5,299 untranslated English entries** across all files:

- **Base Game**: 42 untranslated entries
- **DLC1 (Battle of Steeltown)**: 3,237 untranslated entries
- **DLC2 (Cult of the Holy Detonation)**: 2,020 untranslated entries

These entries were incorrectly marked as complete but remained in English while Spanish versions were properly translated.

## Tools

### 1. `detect-untranslated.py` - Detection Tool

Scans translation files for untranslated English entries using Spanish reference files.

**Features:**
- Detects entries that should be translated (Spanish version is translated)
- Skips technical terms and program identifiers
- Generates detailed reports with line numbers
- Supports scanning individual files or all files

**Usage:**

```bash
# Check base game only
python3 automation/detect-untranslated.py --file base_game

# Check DLC1 only
python3 automation/detect-untranslated.py --file dlc1

# Check DLC2 only
python3 automation/detect-untranslated.py --file dlc2

# Check all files (base + DLC1 + DLC2)
python3 automation/detect-untranslated.py --file all

# Verbose output (show line content)
python3 automation/detect-untranslated.py --file base_game --verbose

# Skip saving report files
python3 automation/detect-untranslated.py --file base_game --no-report
```

**Output Files:**

When untranslated entries are found, the script generates:

1. **Detailed Report**: `automation/.untranslated_{file}_report.txt`
   - Contains line numbers and full line content for each untranslated entry

2. **Line Numbers Only**: `automation/.untranslated_{file}_lines.txt`
   - One line number per line, for programmatic processing

**Exit Codes:**
- `0`: No untranslated entries found
- `1`: Untranslated entries detected or error occurred

### 2. `auto-fix-untranslated.sh` - Automated Fix Tool

Automatically detects and fixes untranslated entries using Claude Code.

**⚠️ IMPORTANT SECURITY WARNING ⚠️**

This script uses dangerous automation features:
- `--dangerously-skip-permissions`: Bypasses all file edit permission checks
- `yes` command: Auto-approves ALL interactive prompts

**ONLY use this script if you:**
- Understand the security implications
- Are running in a sandboxed/VM environment
- Have reviewed the CLAUDE.md translation rules
- Have backups of all translation files

**DO NOT use this script if you are:**
- A beginner or intermediate user
- Unsure about automation scripts
- Running on a production system
- Lacking proper backups

**Features:**
- Exclusive lock (prevents duplicate sessions)
- Scans entire file for untranslated entries
- Applies CLAUDE.md unified translation decision logic
- Triple validation after each fix (structure, action markers, quality)
- Incremental commits (every 10 fixes)
- Memory monitoring and automatic termination
- Detailed logging

**Usage:**

```bash
# Start automated fixing (DANGEROUS - use with caution)
./automation/auto-fix-untranslated.sh

# Remove stale lock file (if script crashed)
./automation/auto-fix-untranslated.sh --unlock
```

**Safety Features:**

1. **Exclusive Lock**: Only one fix session can run at a time
   - Lock file: `automation/.untranslated_fix.lock`
   - Auto-removes stale locks from crashed sessions

2. **Triple Validation** (after EACH edit):
   - Structure validation (`validate_structure_v2.py`)
   - Action marker validation (grep for Japanese in `::action::`)
   - Quality validation (`validate_translation_quality.py`)

3. **Incremental Commits**: Commits every 10 fixes
   - Reduces risk of data loss
   - Easy to rollback if errors occur

4. **Memory Monitoring**: Automatic termination at 5000MB
   - Prevents out-of-memory crashes
   - Logs memory usage every 30 seconds

5. **Detailed Logging**: All operations logged to:
   - `automation/untranslated-fix-automation.log`
   - Session output: `automation/.fix_untranslated_output.log`

**What the Script Does:**

1. **Scan Phase**:
   - Runs `detect-untranslated.py` to find all untranslated entries
   - Generates line number list

2. **Fix Phase** (via Claude Code):
   - For each untranslated entry:
     - Reads context (English, Spanish, Japanese)
     - Applies CLAUDE.md unified translation logic
     - Translates to Japanese using `nouns_glossary.json`
     - Validates structure (quotes, markers, etc.)
     - Commits every 10 fixes

3. **Validation Phase**:
   - Final comprehensive validation
   - Reports remaining issues (if any)

**Expected Completion Time:**

Based on current counts:
- Base Game (42 entries): ~5-10 minutes
- DLC1 (3,237 entries): ~6-8 hours
- DLC2 (2,020 entries): ~4-6 hours
- **Total**: ~10-14 hours (for all 5,299 entries)

## Manual Fix Workflow (Safer Alternative)

For users who prefer manual control or are uncomfortable with automation:

### Step 1: Detect Untranslated Entries

```bash
python3 automation/detect-untranslated.py --file base_game --verbose
```

### Step 2: Review the Report

```bash
cat automation/.untranslated_base_game_report.txt
```

### Step 3: Fix Manually Using Claude Code

Start a Claude Code session and provide the following prompt:

```
以下のファイルに未翻訳の英語エントリが存在します。
automation/.untranslated_base_game_lines.txt に記載された行番号のエントリを、
CLAUDE.mdのルールに従って日本語に翻訳してください。

処理手順:
1. automation/.untranslated_base_game_lines.txt を読み込み
2. 各行番号について、前後の文脈と共に読み込み
3. スペイン語参照ファイルで翻訳可否を判断
4. nouns_glossary.jsonを参照して翻訳
5. 各編集後、必ず検証 (structure, action markers, quality)
6. 10エントリごとにコミット

ファイル:
- English: translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt
- Spanish: translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt
- Japanese: translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt
```

### Step 4: Validate After Manual Fixes

```bash
# Structure validation
python3 translation/validate_structure_v2.py \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt \
  --source translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt \
  --detailed

# Quality validation
python3 translation/validate_translation_quality.py \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt \
  --reference translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt \
  --start-line 390 \
  --end-line 530425 \
  --glossary translation/nouns_glossary.json

# Re-run detection to confirm all entries are fixed
python3 automation/detect-untranslated.py --file base_game
```

## Translation Decision Logic

Both tools use the **CLAUDE.md Unified Translation Decision Logic** (priority order):

1. **English == ""** (empty) → Skip (truly empty entry)

2. **Check do_not_translate list** (Script Node, [Global:], [Switch to], etc.)
   → If found: Keep English (technical term)

3. **Check nouns_glossary.json** (proper nouns: characters, locations, factions)
   → If found: Translate using glossary term

4. **Spanish != "" AND Spanish != English** (Spanish is translated)?
   → Translate to Japanese (normal translatable text)

5. **Otherwise** (Spanish == "" OR Spanish == English):
   → **Translate to Japanese** (default behavior)
   → Includes: proper nouns not yet in glossary, dialogue, descriptions

This logic ensures:
- Technical terms are not translated
- Proper nouns use consistent terminology
- Normal dialogue is translated to Japanese
- Program identifiers remain in English

## Troubleshooting

### Issue: "Another fix session is already running"

**Solution**: Remove stale lock file
```bash
./automation/auto-fix-untranslated.sh --unlock
```

### Issue: Validation errors after fixes

**Solution**: Review the error report and fix manually
```bash
# Check structure errors
cat automation/.structure_errors.log

# Check quality errors
cat automation/.quality_errors.log
```

### Issue: Memory exceeded during automation

**Solution**: Script will automatically terminate and save progress
- Progress is committed every 10 fixes
- Simply re-run the script to continue from last commit

### Issue: Claude Code session stuck

**Solution**: Kill the process and remove lock
```bash
pkill -9 claude
./automation/auto-fix-untranslated.sh --unlock
```

## Recommendations

### For Beginners/Intermediate Users:
- **Use manual fix workflow** (safer, more control)
- Review each translation before committing
- Use `detect-untranslated.py` to find issues
- Fix 10-20 entries at a time

### For Advanced Users:
- **Use automated script** in sandboxed environment only
- Always have backups before running automation
- Monitor logs during execution
- Validate results after completion

### Best Practices:
1. Start with base game (42 entries) as a test
2. Validate thoroughly after each batch
3. Commit frequently (every 10-50 entries)
4. Keep Spanish reference files updated
5. Review glossary terms before translating

## Files Generated

### Detection Phase:
- `automation/.untranslated_{file}_report.txt` - Detailed report
- `automation/.untranslated_{file}_lines.txt` - Line numbers only

### Automation Phase:
- `automation/.fix_untranslated_command.txt` - Claude Code command
- `automation/.fix_untranslated_output.log` - Session output
- `automation/untranslated-fix-automation.log` - Automation log
- `automation/.untranslated_fix.lock` - Exclusive lock file

### Validation Phase:
- `automation/.final_validation.log` - Final validation results
- `automation/.structure_errors.log` - Structure errors (if any)
- `automation/.quality_errors.log` - Quality errors (if any)

## See Also

- `CLAUDE.md` - Project translation rules and guidelines
- `translation/STRICT_TRANSLATION_RULES.md` - Strict workflow documentation
- `translation/STRUCTURE_PROTECTION_RULES.md` - Structure protection rules
- `translation/nouns_glossary.json` - Translation glossary
- `automation/README.md` - Main automation documentation
