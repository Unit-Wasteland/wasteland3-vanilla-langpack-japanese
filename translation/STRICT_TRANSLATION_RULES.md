# Strict Translation Rules

**Created:** 2025-10-29
**Version:** 4.0 (English version for AI - 2025-11-01)
**Primary Document:** See [CLAUDE.md](../CLAUDE.md) for complete translation guidelines

---

## ⚠️ IMPORTANT: Primary Reference

**This document is a supplementary reference. The PRIMARY and AUTHORITATIVE translation rules are in [CLAUDE.md](../CLAUDE.md).**

For AI translation work, **ALWAYS refer to CLAUDE.md first**.

---

## Purpose

This document provides strict translation rules to prevent structural corruption and ensure game functionality. All rules here are derived from and supplementary to CLAUDE.md.

---

## Critical Rules Summary

### 1. Action Markers - ZERO TOLERANCE

**NEVER translate `::action::` marker content.**

```
❌ WRONG: ::sigh:: → ::ため息::
✅ CORRECT: ::sigh:: → ::sigh:: (keep in English)
```

**Reason:** Game engine cannot recognize translated action markers, breaking animations and effects.

**See:** CLAUDE.md Section 5 for detailed action marker rules.

#### 1.1. Action-Only Entries - DO NOT EDIT

**If an entry contains ONLY an action marker and nothing else, DO NOT edit it.**

```
Example:
string data = "::shivers::"     ← DO NOT EDIT (action-only entry)
string data = "::nods::"        ← DO NOT EDIT (action-only entry)
```

**Reason:** Editing action-only entries may accidentally add extra quotes or modify structure.

**DISCOVERED ISSUE (2025-11-02):**
- Line 237076: `string data = "::shivers::"` was accidentally edited to `string data = "::shivers::""` (extra quote added)
- This caused quote count mismatch (2 quotes → 3 quotes)
- Game import would fail

**Prevention:**
1. Before editing, check if entry is action-only
2. If yes, skip editing (preserve source exactly)
3. Validate quote count after any edit

---

### 2. Structure Markers - ABSOLUTE PRESERVATION

**NEVER modify these markers:**

| Marker | Purpose | Rule |
|--------|---------|------|
| `""` | Text boundary (4 quotes total) | NEVER change to `「」`, `""`, or `\"` |
| `[]` | Game variables | NEVER translate content |
| `<>` | HTML tags | NEVER remove or modify |
| `::action::` | Engine commands | NEVER translate |

**See:** CLAUDE.md Section 4 for format preservation rules.

---

### 3. Spanish Reference Logic

**CRITICAL: Correct logic for Spanish reference checking:**

```
if Spanish == "" AND English == "":
    → Skip (truly empty)
elif Spanish == "" AND English != "":
    → Keep English text (program identifier)
elif Spanish != "" AND Spanish != English:
    → Translate to Japanese
```

**WRONG logic (DO NOT USE):**
```
if Spanish == "":
    skip_translation()  # ❌ This leaves English text untranslated
```

**See:** CLAUDE.md Section 7 for Spanish reference rules.

---

### 4. Technical Terms - DO NOT TRANSLATE

**NEVER translate:**
- `Script Node [number]`
- `[Switch to ...]`
- `[Global: ...]`
- `[Dropset: ...]`
- `[Reward: ...]`
- `DEBUG`

**See:** CLAUDE.md Section 6 for technical term list.

---

### 5. Mandatory Validation - DUAL CHECK

**BEFORE EVERY COMMIT, run BOTH validations:**

```bash
# Validation 1: Structure (must show 0 errors)
python3 translation/validate_structure_v2.py TARGET_FILE \
  --source SOURCE_FILE --detailed

# Validation 2: Quality (must show 0 issues)
python3 translation/validate_translation_quality.py TARGET_FILE \
  --start-line START --end-line END
```

**If EITHER fails → STOP → Fix → Re-validate → Only then commit**

**See:** CLAUDE.md "Step 3: Quality Validation" for validation requirements.

---

### 6. Translation Range

**CORRECTED (2025-11-01):**
- **Line 390**: First translatable entry (Ananda Rabindranath dialogue)
- **Lines 390-665**: 3 entries (previously skipped - MUST translate)
- **Line 666+**: Main translation content

**Previous incorrect assumption:** Translation started at line 666
**Correct starting point:** Line 390

**See:** CLAUDE.md "Sequential Processing Approach" for translation range details.

---

### 7. Batch Processing - ABSOLUTELY FORBIDDEN

**NEVER use:**
- Scripts for bulk fixing
- Automated translation tools
- Multiple entry simultaneous processing

**ALWAYS use:**
- Manual one-by-one processing
- Visual verification after each edit
- Small chunks (10-20 entries for fixes, 150-200 lines for new translation)

**See:** CLAUDE.md "Memory Management" and "forbidden_actions" in .retranslation_progress.json

---

## Unity StringTable Quote Format

**Understanding the 4-quote format:**

```
string data = ""Japanese text here""
              ↑↑              ↑↑
              12              34
```

1. Quote 1: String delimiter (Unity format)
2. Quote 2: Text boundary marker (Unity format)
3. Quote 3: Text boundary marker (Unity format)
4. Quote 4: String delimiter (Unity format)

**This is NOT an escape sequence** - it's Unity's literal format requirement.

**FORBIDDEN:**
- ❌ `\"Japanese text\"` (backslash escaping)
- ❌ `「Japanese text」` (Japanese brackets)
- ❌ `"Japanese text"` (2-quote format when source has 4)

---

## Quality Issues Discovered (2025-11-01)

### Issue 1: Action Markers Translated
- **Count:** 97 instances
- **Example:** `::sigh::` → `::ため息::`
- **Impact:** Game engine cannot recognize, breaks animations
- **Fix:** Manual correction using English source

### Issue 2: Untranslated English Entries
- **Count:** 6,982 entries
- **Cause:** Incorrect Spanish reference logic
- **Impact:** English text displays in Japanese mode
- **Fix:** Manual translation with correct Spanish logic

### Issue 3: Skipped Range
- **Range:** Lines 390-665 (3 entries)
- **Cause:** Assumed line 666 was start
- **Impact:** Missing translations at file beginning
- **Fix:** Translate these 3 entries manually

**See:** translation/ROOT_CAUSE_ANALYSIS.md for detailed analysis (human-readable, Japanese)

---

## Workflow Summary

### For Each Translation Session:

1. **Read** 150-200 line chunk (English + Spanish + Japanese)
2. **Check** Spanish reference for each entry
3. **Translate** if Spanish shows translation (keep action markers in English)
4. **Validate** with BOTH scripts after edit
5. **Verify** action markers manually with grep
6. **Commit** only when both validations show 0 errors/issues
7. **Update** .retranslation_progress.json

### Manual Verification Commands:

```bash
# Check for Japanese in action markers (should return nothing)
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE

# Extract all action markers for review
grep -o '::[^:]*::' TARGET_FILE

# Count untranslated entries
grep 'string data = ""[A-Z]' TARGET_FILE | wc -l
```

---

## Related Documentation

### AI-Facing Documents (English):
- **[CLAUDE.md](../CLAUDE.md)** - PRIMARY reference for all translation work
- **[STRUCTURE_PROTECTION_RULES.md](STRUCTURE_PROTECTION_RULES.md)** - Structure marker details
- **[RETRANSLATION_WORKFLOW.md](RETRANSLATION_WORKFLOW.md)** - Workflow guide

### Human-Facing Documents (Japanese):
- **[CRITICAL_RULES.md](CRITICAL_RULES.md)** - 絶対厳守ルール（人間向け）
- **[ROOT_CAUSE_ANALYSIS.md](ROOT_CAUSE_ANALYSIS.md)** - 根本原因分析
- **[quality_issues_report.md](quality_issues_report.md)** - 品質問題レポート

### Tools:
- **validate_structure_v2.py** - Structure validation
- **validate_translation_quality.py** - Quality validation (NEW - 2025-11-01)
- **nouns_glossary.json** - Translation glossary

---

## Emergency Rules (If Unsure)

**When in doubt:**

1. **Check CLAUDE.md first** - it has the authoritative rules
2. **Compare with English source** - verify structure matches exactly
3. **Check Spanish reference** - determine if translation is needed
4. **Keep markers unchanged** - ALL `::action::`, `[]`, `<>`, `""` stay as-is
5. **Run both validations** - before any commit
6. **Ask for clarification** - if uncertain about any rule

---

**Last Updated:** 2025-11-01
**Primary Reference:** [CLAUDE.md](../CLAUDE.md)
