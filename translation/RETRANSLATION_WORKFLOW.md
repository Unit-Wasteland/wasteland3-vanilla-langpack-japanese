# Retranslation Workflow

**Version:** 3.0 (English version for AI - 2025-11-01)
**Primary Document:** See [CLAUDE.md](../CLAUDE.md) for complete workflow details

---

## ⚠️ IMPORTANT: Primary Reference

**This document is supplementary. The PRIMARY and AUTHORITATIVE workflow is in [CLAUDE.md](../CLAUDE.md).**

For AI translation work, **ALWAYS refer to CLAUDE.md first**.

---

## Overview

This document defines the workflow for fixing structural corruption discovered in translation files.

### 🔴 CRITICAL: Work Sequence - MANDATORY 🔴

**Translation work MUST follow this strict sequence:**

1. **Base Game (169,712 entries)** - Complete to 100% with strict validation
2. **DLC1: Battle of Steeltown (38,554 entries)** - Start ONLY after base game 100% complete
3. **DLC2: Cult of the Holy Detonation (24,152 entries)** - Start ONLY after DLC1 100% complete

**FORBIDDEN:**
- ❌ Starting DLC1 or DLC2 before base game reaches 100%
- ❌ Working on multiple files (base/DLC1/DLC2) simultaneously
- ❌ Prioritizing DLC content over base game content

**Current Status:**
- Base Game: 19% (32,448/169,712) - **IN PROGRESS** (continue from line 5005)
- DLC1: 0% (not started) - **DO NOT START** until base game 100%
- DLC2: 0% (not started) - **DO NOT START** until DLC1 100%

### Background

**Complete Restart Reason (2nd time):**

77,533 structural errors (45.7% of entries) were discovered in the previous version. Unity StringTable structural markers (`""`) were incorrectly converted to Japanese brackets (`「」`, `『』`), or had quotes improperly added/removed, causing game import failures.

**Problem Examples:**
- Broken: `string data = "「Japanese text」"` (bracket conversion)
- Broken: `string data = ""English text""` (unnecessary quotes added)
- Broken: `string data = "Quoted text"` (missing quotes)
- Correct: `string data = ""Japanese text""` (Unity format)

### Solution Approach (Strict Workflow)

1. **Use English files as new base** (100% structure guarantee)
2. **Use Spanish files for translatability judgment** (reliable program identifier detection)
3. **Validate after EACH edit** (immediate structural corruption detection and fix)
4. **Sequential processing** (NO skipping, NO prioritization)
5. **Batch processing STRICTLY FORBIDDEN** (manual individual processing only for quality assurance)

**Reference Documents:**
- **[CLAUDE.md](../CLAUDE.md)** - Main translation guidelines (PRIMARY)
- **[STRICT_TRANSLATION_RULES.md](STRICT_TRANSLATION_RULES.md)** - Strict rules summary
- **[STRUCTURE_PROTECTION_RULES.md](STRUCTURE_PROTECTION_RULES.md)** - Structure protection details
- **validate_structure_v2.py** - Structure validation script (mandatory tool)
- **validate_translation_quality.py** - Quality validation script (NEW - 2025-11-01)

---

## File Structure

```
translation/
├── source/v1.6.9.420.309496/
│   ├── en_US/              # English source (structure reference, new base)
│   │   ├── StringTableData_English-CAB-*.txt (530,425 lines, 169,712 entries)
│   │   ├── DLC1/StringTableData_English-CAB-*.txt (120,559 lines)
│   │   └── DLC2/StringTableData_English-CAB-*.txt (77,353 lines)
│   └── es_ES/              # Spanish (translatability judgment - MANDATORY)
│       ├── StringTableData_Spanish-CAB-*.txt (530,425 lines)
│       ├── DLC1/StringTableData_Spanish-CAB-*.txt (120,559 lines)
│       └── DLC2/StringTableData_Spanish-CAB-*.txt (77,353 lines)
├── target/v1.6.9.420.309496/ja_JP/
│   ├── StringTableData_English-CAB-*.txt  # Work target (copied from English)
│   ├── DLC1/
│   └── DLC2/
├── backup_broken/          # Broken Japanese translation (reference only, NOT recommended)
│   ├── StringTableData_English-CAB-*.txt (77,533 structural errors)
│   ├── DLC1/
│   └── DLC2/
└── nouns_glossary.json     # Translation glossary
```

---

## Translation Range (CORRECTED 2025-11-01)

**Previous incorrect assumption:** Translation started at line 666

**CORRECTED:**
- **Line 390**: First non-empty translatable entry (Ananda Rabindranath dialogue)
- **Lines 390-665**: 3 entries (previously skipped - MUST translate)
- **Line 666+**: Main translation content

**See:** CLAUDE.md "Sequential Processing Approach" for details.

---

## Workflow Phases

### Phase 0: Environment Preparation (One-time Setup)

**Status:** ✅ COMPLETED (2025-10-29)

1. Backed up current target files to `backup_broken/`
2. Copied English source as new clean base to `target/ja_JP/`
3. Initialized progress file: `.retranslation_progress.json`
4. Created validation scripts and documentation

**Result:** Clean English base with 100% correct structure, ready for translation.

---

### Phase 1: Sequential Retranslation (In Progress)

**Status:** 🔄 IN PROGRESS - BASE GAME ONLY

**Current Progress (2025-11-10):**
- **Base Game Translated:** 32,448 entries (19.1% of 169,712)
- **Base Game Remaining:** 137,264 entries (80.9%)
- **Base Game Current Line:** 5,005
- **DLC1 Status:** NOT STARTED (0% - will begin after base game 100%)
- **DLC2 Status:** NOT STARTED (0% - will begin after DLC1 100%)
- **Overall Progress:** 32,448 / 232,418 entries (13.96%)

**Workflow for Each Entry:**

1. **Read** 150-200 line chunk:
   - English source
   - Spanish reference
   - Japanese target

2. **Check Spanish reference:**
   ```
   if Spanish == "" AND English == "":
       → Skip (truly empty)
   elif Spanish == "" AND English != "":
       → Keep English text (program identifier)
   elif Spanish != "" AND Spanish != English:
       → Translate to Japanese
   ```

3. **Translate** (if Spanish shows translation):
   - Use `nouns_glossary.json` for consistency
   - **KEEP all action markers in English** (`::action::`)
   - Preserve all structure markers (`""`, `[]`, `<>`)
   - Keep technical terms in English

4. **Validate BOTH scripts** (MANDATORY):
   ```bash
   # Structure validation (must show 0 errors)
   python3 validate_structure_v2.py TARGET_FILE \
     --source SOURCE_FILE --detailed

   # Quality validation (must show 0 issues)
   python3 validate_translation_quality.py TARGET_FILE \
     --start-line START --end-line END
   ```

5. **Manual verification:**
   ```bash
   # Check for Japanese in action markers (should return nothing)
   grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
   ```

6. **Commit** (only if both validations pass):
   - Update `.retranslation_progress.json`
   - Commit every 500 entries or major section
   - Push to remote for backup

7. **Repeat** until all entries completed

**See:** CLAUDE.md "Standard strict retranslation workflow" for detailed steps.

---

### Phase 2: Quality Fixes (NEW - 2025-11-01)

**Status:** 🆕 IDENTIFIED - FIXING IN PROGRESS

**Issues Discovered:**

1. **Action Markers Translated (97 instances)**
   - Example: `::sigh::` → `::ため息::`
   - Fix: Manual correction using English source
   - Priority: **HIGHEST** (breaks game functionality)

2. **Untranslated English Entries (6,982 instances)**
   - Cause: Incorrect Spanish reference logic
   - Fix: Manual translation with correct logic
   - Priority: **HIGH** (poor user experience)

3. **Skipped Range (Lines 390-665, 3 entries)**
   - Cause: Assumed line 666 was start
   - Fix: Translate these entries manually
   - Priority: **HIGH** (missing content at file beginning)

**Fix Workflow:**

- **Chunk size:** 10-20 entries per session for fixes
- **Validation:** BOTH scripts after each fix batch
- **Commit:** After each successful fix batch
- **NO batch processing:** Manual one-by-one fixes only

**See:** translation/ROOT_CAUSE_ANALYSIS.md for detailed cause analysis (human-readable, Japanese)

---

## Progress Tracking

**File:** `.retranslation_progress.json`

**Structure:**
```json
{
  "workflow_version": "3.0",
  "workflow_name": "strict_retranslation",
  "base_language": "en_US",
  "target_language": "ja_JP",
  "reference_language": "es_ES",
  "files": {
    "base_game": {
      "total_entries": 169712,
      "entries_translated": 32448,
      "entries_untranslated": 137264,
      "current_line": 5005,
      "status": "in_progress"
    },
    "dlc1": {
      "total_entries": 38554,
      "entries_completed": 0,
      "entries_untranslated": 38554,
      "status": "not_started"
    },
    "dlc2": {
      "total_entries": 24152,
      "entries_completed": 0,
      "entries_untranslated": 24152,
      "status": "not_started"
    }
  },
  "total_entries_completed": 32448,
  "total_entries": 232418
}
```

**Update Frequency:** After each commit

### ⚠️ CRITICAL: Progress File Update Checklist

**When updating `.retranslation_progress.json`, you MUST update ALL of the following values:**

1. **File-specific counters** (base_game, dlc1, or dlc2):
   - `entries_translated` (or `entries_completed`)
   - `entries_untranslated` (or `entries_untranslated_real`)
   - `current_line`
   - `completion_rate`
   - `note` (session summary)

2. **Global counters** (CRITICAL - automation monitoring depends on these):
   - `total_entries_completed` = sum of all file entries_translated/completed
   - `total_entries_untranslated` = total_entries - total_entries_completed
   - `overall_completion_rate` = (total_entries_completed / total_entries) * 100

3. **Commit tracking**:
   - `last_commit_hash`
   - `last_commit_message`

**Example Calculation:**
```
base_game.entries_translated = 39,590
dlc1.entries_translated = 9,385
dlc2.entries_completed = 0
→ total_entries_completed = 39,590 + 9,385 + 0 = 48,975
→ total_entries_untranslated = 232,418 - 48,975 = 183,443
→ overall_completion_rate = 48,975 / 232,418 = 21.1%
```

**⚠️ FAILURE TO UPDATE `total_entries_completed` WILL CAUSE AUTOMATION TO FAIL**

The automation script (`auto-retranslate.sh`) monitors `total_entries_completed` to track
progress. If this value is not updated, the script will detect 0 entries translated and
stop after 3 consecutive sessions with 0 progress.

**Incident Reference:** 2025-11-12 - Sessions #5, #6, #7 updated `base_game.entries_translated`
but not `total_entries_completed`, causing automation to incorrectly detect 3 consecutive
sessions with 0 entries and halt. (Commit: 9f0656f)

---

## Validation Requirements (UPDATED 2025-11-01)

### Before EVERY Commit:

**1. Structure Validation (existing)**
```bash
python3 translation/validate_structure_v2.py TARGET_FILE \
  --source SOURCE_FILE --detailed
```

**Checks:**
- Line count matches source
- Quote count per line matches source
- NO Japanese brackets in structure
- Game variables preserved
- HTML tags preserved

**Expected:** `Total errors: 0`

---

**2. Quality Validation (NEW - added 2025-11-01)**
```bash
python3 translation/validate_translation_quality.py TARGET_FILE \
  --start-line START --end-line END
```

**Checks:**
- NO action markers contain Japanese characters
- NO untranslated English entries (where Spanish shows translation)
- Technical terms preserved

**Expected:** `Total issues found: 0`

---

**3. Manual Verification**
```bash
# Check for Japanese in action markers (should return nothing)
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE

# Review git diff for structure changes (should only be text changes)
git diff TARGET_FILE
```

---

**If ANY validation fails:**
1. STOP immediately - DO NOT commit
2. Review error/issue report
3. Fix problems manually, one by one
4. Re-run ALL validations
5. Only commit when all show 0 errors/issues

---

## Critical Rules

### Action Markers - ZERO TOLERANCE
```
❌ NEVER translate: ::sigh:: → ::ため息::
✅ ALWAYS keep: ::sigh:: → ::sigh::
```

### Spanish Reference Logic
```
Spanish == "" AND English != "" → Keep English (don't translate)
Spanish != "" AND Spanish != English → Translate to Japanese
```

### Structure Markers - ABSOLUTE PRESERVATION
```
"" (double quotes)  → NEVER change to 「」 or \"
[]  (brackets)      → NEVER translate content
<>  (HTML tags)     → NEVER remove
::action::          → NEVER translate
```

### Batch Processing - ABSOLUTELY FORBIDDEN
```
❌ Scripts for bulk fixing
❌ Automated translation
❌ Multiple entry processing

✅ Manual one-by-one
✅ Visual verification
✅ Small chunks (10-20 fixes, 150-200 new)
```

---

## Common Mistakes to Avoid

1. **Translating action markers**
   - ❌ `::sigh::` → `::ため息::`
   - ✅ Keep `::sigh::` in English

2. **Incorrect Spanish logic**
   - ❌ `Spanish == "" → skip translation`
   - ✅ `Spanish == "" AND English != "" → keep English`

3. **Using Japanese brackets**
   - ❌ `「Japanese text」`
   - ✅ `""Japanese text""`

4. **Skipping validation**
   - ❌ Commit without validation
   - ✅ Run BOTH validations before commit

5. **Batch processing**
   - ❌ Fix multiple entries with script
   - ✅ Fix manually one by one

---

## Related Documentation

### AI-Facing (English):
- **[CLAUDE.md](../CLAUDE.md)** - PRIMARY translation guidelines (start here)
- **[STRICT_TRANSLATION_RULES.md](STRICT_TRANSLATION_RULES.md)** - Rules summary
- **[STRUCTURE_PROTECTION_RULES.md](STRUCTURE_PROTECTION_RULES.md)** - Structure details

### Human-Facing (Japanese):
- **[CRITICAL_RULES.md](CRITICAL_RULES.md)** - 絶対厳守ルール
- **[ROOT_CAUSE_ANALYSIS.md](ROOT_CAUSE_ANALYSIS.md)** - 根本原因分析
- **[quality_issues_report.md](quality_issues_report.md)** - 品質問題レポート

### Tools:
- **validate_structure_v2.py** - Structure validation
- **validate_translation_quality.py** - Quality validation (NEW)
- **nouns_glossary.json** - Translation glossary

---

## Next Steps

**🔴 MANDATORY: Complete Base Game First**

The ONLY priority is to complete the base game translation to 100% before starting any DLC work.

**Current Base Game Status:**
- Progress: 19.1% (32,448 / 169,712 entries)
- Continue from: Line 5005
- Remaining: 137,264 entries (80.9%)

**Workflow:**
1. Continue sequential translation from line 5005
2. Process in 150-200 line chunks with strict validation
3. Commit every 500 entries
4. Validate structure AND quality after EVERY edit
5. NO skipping, NO prioritization

**After Base Game 100% Complete:**
1. Run full validation on base game file
2. Verify NO structural errors, NO quality issues
3. Only then begin DLC1 translation from line 1
4. DLC2 begins only after DLC1 reaches 100%

**See:** CLAUDE.md for detailed execution guidelines.

---

**Last Updated:** 2025-11-10 (DLC progress reset, base game priority enforced)
**Primary Reference:** [CLAUDE.md](../CLAUDE.md)
