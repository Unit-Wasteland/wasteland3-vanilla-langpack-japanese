# Error Report: Quote Count Mismatch (2025-11-06)

## Summary

**Date:** 2025-11-06 03:58:20
**Session:** R3-119
**Commit:** 130dde2
**Errors Found:** 6 quote count mismatch errors
**Impact:** Automation stopped, manual fix required

## Error Details

### Affected Lines

| Line | Source Quotes | Target Quotes | Error Type |
|------|---------------|---------------|------------|
| 117578 | 6 | 9 | Internal quotes doubled (3 locations) |
| 117612 | 6 | 8 | Internal quotes doubled (2 locations) |
| 117616 | 6 | 7 | Quote before action marker doubled |
| 117872 | 6 | 7 | Quote before \r\n doubled |
| 117892 | 4 | 5 | Quote before action marker doubled |
| 117894 | 6 | 7 | Internal quote doubled |

### Error Pattern

All errors followed the same pattern: **Internal quotes (not at start/end of string data) were incorrectly changed from single `"` to double `""`.**

**Example:**

❌ **WRONG** (what was produced):
```
string data = ""First sentence""\r\n\r\n""Second sentence""
```

✅ **CORRECT** (what should have been):
```
string data = ""First sentence"\r\n\r\n"Second sentence""
```

## Root Cause Analysis

### Primary Cause: Misunderstanding of Unity String Format

The translation process incorrectly applied Unity's double-quote rule to internal quotes:

- **Unity rule**: String data content must be wrapped with `""` at start and end
- **Misapplication**: All quotes in the content were doubled, including internal dialogue separators
- **Correct behavior**: Only the outermost quotes (start and end) should be doubled; internal quotes remain single

### Secondary Cause: Validation Gap

Session R3-119 reported "Structure validation: 0 errors" but errors existed:

**Possible reasons:**
1. Validation ran on wrong line range (didn't include affected lines)
2. Validation ran before all edits were completed
3. Timing issue between edit completion and validation execution

### Tertiary Cause: Complex Dialogue Format

Errors occurred specifically in multi-sentence dialogues with:
- Multiple sentences separated by `\r\n` or `\n\n\n`
- Action markers (e.g., `::sob::`, `::sigh::`) between sentences
- Dialogue broken across multiple speakers/lines

## Prevention Measures

### 1. Documentation Enhancement (COMPLETED)

Created this error report documenting:
- Error pattern with examples
- Correct vs incorrect quote handling
- Specific scenarios to watch for

### 2. Validation Improvements (RECOMMENDED)

**Immediate actions:**
- ✅ Run full-file validation before each commit (already in automation)
- ⚠️ Add validation after EVERY Edit operation (not just at session end)
- ⚠️ Log validation line range to ensure it covers edited content

**Automation script changes needed:**
```bash
# After each edit, validate immediately
after_edit() {
    local target_file="$1"
    local source_file="$2"

    # Validate entire file (not just edited range)
    python3 translation/validate_structure_v2.py \
        "$target_file" --source "$source_file" --detailed

    if [ $? -ne 0 ]; then
        echo "[ERROR] Validation failed immediately after edit"
        exit 1
    fi
}
```

### 3. Translation Rules Clarification (RECOMMENDED)

Add to `translation/STRUCTURE_PROTECTION_RULES.md`:

**Section: Internal Quote Handling Rules**

```markdown
## Internal Quotes in Multi-Sentence Dialogues

### Rule: Only Outermost Quotes Are Doubled

Unity's StringTable format requires exactly FOUR quotes for simple content:
- 2 quotes at start: ""
- 2 quotes at end: ""

For multi-sentence dialogues, internal quotes between sentences remain SINGLE:

✅ CORRECT:
string data = ""First sentence"\r\n\r\n"Second sentence""
              ^^               ^          ^              ^^
              doubled          single     single         doubled
              (start)          (internal) (internal)     (end)

❌ WRONG:
string data = ""First sentence""\r\n\r\n""Second sentence""
              ^^               ^^        ^^               ^^
              All quotes doubled - BREAKS GAME IMPORT!

### Common Scenarios

**1. Newline-separated sentences:**
- Source: `""Sentence one."\n\n\n"Sentence two.""`
- Keep single quotes around newline markers

**2. Action markers between sentences:**
- Source: `""I can't..." ::sob::\n\n\n"Please forgive me.""`
- Quote before action marker: SINGLE
- Quote after action marker: SINGLE

**3. Carriage return separated:**
- Source: `""Question?" \r\n\r\n"Answer.""`
- Quote before \r\n: SINGLE
- Quote after \r\n\r\n: SINGLE

### Verification Command

After editing any line with multiple sentences, verify quote count:
```bash
# Count quotes in specific line
sed -n 'LINE_NUMp' target_file.txt | grep -o '"' | wc -l
sed -n 'LINE_NUMp' source_file.txt | grep -o '"' | wc -l
# Both counts MUST match exactly
```
```

### 4. Testing Procedure (RECOMMENDED)

Add test cases to validation script for specific patterns:

```python
# In validate_structure_v2.py, add test cases:

TEST_CASES = [
    {
        'name': 'Multi-sentence with newline',
        'source': 'string data = ""First sentence."\n\n\n"Second sentence.""',
        'expected_quotes': 6,
        'description': 'Newline-separated sentences with single internal quotes'
    },
    {
        'name': 'Action marker between sentences',
        'source': 'string data = ""I can\'t..." ::sob::\n\n\n"Please."',
        'expected_quotes': 4,
        'description': 'Action marker requires single quote before and after'
    },
    {
        'name': 'Carriage return separated',
        'source': 'string data = ""Question?" \r\n\r\n"Answer.""',
        'expected_quotes': 6,
        'description': 'Carriage return separation with single internal quotes'
    }
]
```

### 5. Automation Enhancement (RECOMMENDED)

**Pre-commit validation:**
- Validate entire file (not just edited range)
- Block commit if any validation errors found
- Log validation results to session log

**Real-time monitoring:**
- Add quote count check after each Edit tool use
- Compare with source immediately
- Alert on mismatch before proceeding

## Resolution

### Fixes Applied

All 6 errors were manually fixed by changing internal doubled quotes back to single quotes:

1. Line 117578: 3 internal quotes changed from `""` → `"`
2. Line 117612: 2 internal quotes changed from `""` → `"`
3. Line 117616: 1 internal quote changed from `""` → `"`
4. Line 117872: 1 internal quote changed from `""` → `"`
5. Line 117892: 1 internal quote changed from `""` → `"`
6. Line 117894: 1 internal quote changed from `""` → `"`

### Validation Results

**Structure validation:** ✅ 0 errors (passed)
**Quality validation:** ✅ 0 issues related to fixed lines (passed)

Note: 4295 untranslated entries remain, but these are expected (work in progress).

### Commit

Fixes committed with message:
```
Fix quote count mismatch errors from Session R3-119

- Fixed 6 quote count errors (lines 117578, 117612, 117616, 117872, 117892, 117894)
- Root cause: Internal quotes incorrectly doubled during translation
- All internal quotes changed from "" back to " to match source format
- Validation: Structure 0 errors, Quality 0 issues
- Documentation: Created ERROR_REPORT_20251106_QUOTE_MISMATCH.md
```

## Lessons Learned

1. **Always match source quote count exactly** - this is non-negotiable for Unity format
2. **Internal quotes ≠ Outer quotes** - only start/end use `""`, middle uses `"`
3. **Validate immediately after edits** - don't wait until session end
4. **Complex dialogues need extra care** - multi-sentence content is high-risk for quote errors
5. **Trust validation scripts** - automation caught this before damage spread

## Status

- ✅ Errors identified and fixed
- ✅ Root cause documented
- ✅ Prevention measures documented
- ⏳ Automation enhancements pending implementation
- ⏳ Documentation updates pending review

**Next Steps:**
1. Commit fixes
2. Update automation script with immediate validation
3. Add test cases to validation script
4. Update STRUCTURE_PROTECTION_RULES.md
5. Resume automation from line 117970
