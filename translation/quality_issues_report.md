# Translation Quality Issues Report - UPDATED

**Date**: 2025-11-01 (Latest scan)
**Scan Range**: Lines 390-224,348 (15,765 translated entries)
**Previous Report**: Lines 666-224,348
**Total Issues Found**: 7,004

---

## Executive Summary

**CRITICAL** translation quality issues have been identified in the retranslated content:

1. **Action Markers Translated to Japanese**: 20 instances across 10 unique lines
   - **Impact**: CRITICAL - Breaks game animations, sound effects, and visual effects
   - **Cause**: Action markers (::action::) were incorrectly translated to Japanese
   - **Status**: Ready for immediate fix

2. **Untranslated English Entries**: 6,984 instances
   - **Impact**: CRITICAL - Major portions of game dialogue remain in English
   - **Cause**: Incorrect Spanish reference logic (empty Spanish = skip translation)
   - **Status**: Requires systematic retranslation

---

## Issue 1: Action Markers Translated to Japanese

### Problem Description

Action markers are game engine control commands that trigger character animations, sounds, and visual effects. They MUST remain in English for the game engine to recognize them.

### Affected Lines (Current Scan: Lines 390-224,348)

| Line | Japanese (WRONG) | English (CORRECT) |
|------|------------------|-------------------|
| 199836 | `::嗅ぐ::` | `::sniffs::` |
| 200364 | `::震える::` | `::shivers::` |
| 200420 | `::ブリブリブリィィィ::` | `::FRRRRAPPPPPP::` |
| 201524 | `::ウィーン::` | `::whirrs::` |
| 220164 | `::雑音::` (×4) | `::Static::` / `::Static:` |
| 220166 | `::雑音::` (×3) | `::Static:` |
| 220168 | `::雑音::` (×3) | `::Static::` |
| 220228 | `::雑音::` | `::static::` |
| 221324 | `::ノイズ::` | `::static::` |
| 221372 | `::ノイズ::` | `::static::` |
| 223384 | `::鼻を鳴らす::` | `::snorts::` |
| 223470 | `::頷く::` | `::nods::` |
| 224332 | `::あくびをする::` | `::yawns::` |

**Total**: 10 unique lines, 20 marker instances

### Previously Identified Issues (From earlier scan)

The previous report identified 100+ action marker issues including:
- Music cues: `::クラシックロック曲が流れる::`, `::ロックバラードが流れる::`, etc.
- Emotions: `::ため息::`, `::すすり泣く::`, `::悲鳴を上げる::`, etc.
- Actions: `::肩をすくめる::`, `::うなずく::`, `::震える::`, etc.
- Sounds: `::静電音::`, `::モデム通信音::`, etc.

**Note**: Some of these may have been fixed in recent commits (e.g., commits cca15ae, de6856b, c6e9569, fae09c1 mention action marker fixes).

### Impact Assessment

- **Gameplay Impact**: Character animations will not play correctly
- **Audio Impact**: Sound effects tied to action markers will fail
- **Visual Impact**: Visual effects triggered by markers will not appear
- **Player Experience**: Significantly degraded immersion

### Fix Strategy

1. Read English source for each affected line
2. Replace Japanese action markers with English equivalents
3. Preserve surrounding Japanese text
4. Validate with `validate_translation_quality.py`
5. Commit fixes with clear documentation

---

## Issue 2: Untranslated English Entries

### Problem Description

6,984 entries remain in English when they should be translated to Japanese. This was caused by incorrect Spanish reference logic.

### Root Cause: Incorrect Spanish Reference Logic

**WRONG Logic (used previously)**:
```python
if Spanish == "":
    skip_translation()  # ❌ WRONG - leaves English text untranslated
```

**CORRECT Logic (should be used)**:
```python
if Spanish == "" AND English == "":
    skip()  # Truly empty entry
elif Spanish == "" AND English != "":
    keep_english_text()  # Program identifier (no translation needed)
elif Spanish != "" AND Spanish != English:
    translate_to_japanese()  # Normal translatable text
```

### Sample Untranslated Entries

| Line Range | Description | Example |
|------------|-------------|---------|
| 390-392 | Ananda Rabindranath dialogue | "Hello, Rangers? This is Ananda Rabindranath..." |
| 1462-1482 | Asphalt G / Carla truck theft radio dialogue | "Breaker-breaker. This is Asphalt G, requesting assistance..." |
| 4362-4516 | Elijah Ward / Theodoric Curie dialogue | "Hello, hello. This is Elijah Ward of Broadmoor Heights..." |

**Total**: 6,984 untranslated entries

### Impact Assessment

- **Translation Completeness**: Only ~56% actually translated (8,781 out of 15,765)
- **Player Experience**: Major portions of dialogue inaccessible to Japanese players
- **Localization Quality**: Unacceptable for release

### Fix Strategy

1. **Immediate**: Use `validate_translation_quality.py` to identify all untranslated entries
2. **Spanish Reference**: For each untranslated entry, check Spanish file:
   - If Spanish translated → Translate to Japanese
   - If Spanish empty → Keep English (program identifier)
3. **Batch Translation**: Process in chunks of 50-100 entries
4. **Validation**: Run both validation scripts after each batch
5. **Progress Tracking**: Update `.retranslation_progress.json` with fix progress

---

## Root Cause Analysis

### Action Marker Issue

**Root Cause**: Missing validation during translation workflow
- **Contributing Factor 1**: No real-time action marker validation
- **Contributing Factor 2**: Action markers appear similar to regular text to translator
- **Contributing Factor 3**: AI translation defaults to "translate everything"

**Prevention**:
- Implement mandatory pre-commit validation with `validate_translation_quality.py`
- Add action marker preservation rules to glossary
- Update automation scripts to include quality checks

### Untranslated Entry Issue

**Root Cause**: Misunderstanding of Spanish reference logic
- **Contributing Factor 1**: Spanish empty (`""`) misinterpreted as "skip this entry"
- **Contributing Factor 2**: No differentiation between empty source and program identifiers
- **Contributing Factor 3**: Missing validation for translation completeness

**Prevention**:
- Update Spanish reference logic in `STRICT_TRANSLATION_RULES.md`
- Add untranslated entry check to validation workflow
- Implement translation rate monitoring per session

---

## Fix Implementation Plan

### Phase 1: Action Marker Fixes (Priority: CRITICAL)

**Scope**: 10 lines, 20 marker instances
**Estimated Time**: 30-60 minutes
**Risk**: Low

**Steps**:
1. Read lines 199836, 200364, 200420, 201524, 220164, 220166, 220168, 220228, 221324, 221372, 223384, 223470, 224332
2. Read English source for each line to get correct action markers
3. Replace Japanese action markers with English equivalents
4. Preserve surrounding Japanese text
5. Validate with both scripts:
   - `validate_structure_v2.py` (structure)
   - `validate_translation_quality.py` (quality)
6. Commit: "Fix action markers batch 5: Restore English (10 lines, 20 instances, lines 199836-224332)"

### Phase 2: Untranslated Entry Fixes (Priority: CRITICAL)

**Scope**: 6,984 entries
**Estimated Time**: Multiple sessions (20-30 hours distributed)
**Risk**: Medium (requires careful Spanish reference checking)

**Approach**:
- **Batch Size**: 50-100 entries per batch
- **Spanish Reference**: MANDATORY for each entry
- **Validation**: After each batch (both scripts)
- **Commit Frequency**: Every 100 entries
- **Total Batches**: ~70-140 batches

**Workflow per Batch**:
1. Extract next 50-100 untranslated line numbers from detailed report
2. Read English source, Spanish reference, and Japanese target
3. For each entry:
   - Check Spanish: If translated → Translate to Japanese (using glossary)
   - Check Spanish: If empty AND English has content → Verify context:
     - If program identifier (Script Node, DEBUG, etc.) → Keep English
     - If dialogue/narrative → ERROR, investigate further
4. Edit Japanese target file
5. Run both validation scripts:
   - `validate_structure_v2.py TARGET --source SOURCE --detailed` (expect 0 errors)
   - `validate_translation_quality.py TARGET --start-line X --end-line Y` (expect 0 issues)
6. If validation fails → Fix issues → Re-validate
7. Commit with detailed message (e.g., "Translate untranslated entries: Lines 390-490 (100 entries)")

### Phase 3: Automated Validation System (Priority: HIGH)

**Scope**: Prevent future issues
**Estimated Time**: 1 hour

**Tasks**:
1. Update automation script (`auto-retranslate.sh`) to include quality validation
2. Create pre-commit hook for manual sessions
3. Update `CRITICAL_RULES.md` with mandatory validation requirements
4. Document validation workflow in `STRICT_TRANSLATION_RULES.md`

---

## Validation Checklist (MANDATORY)

Before committing ANY translation work, BOTH validations must pass with 0 errors/issues:

### 1. Structure Validation
```bash
python3 translation/validate_structure_v2.py \
  translation/target/v1.6.9.420.309496/ja_JP/FILENAME.txt \
  --source translation/source/v1.6.9.420.309496/en_US/FILENAME.txt \
  --detailed
```
**Expected Output**: `Total errors: 0`

### 2. Quality Validation
```bash
python3 translation/validate_translation_quality.py \
  translation/target/v1.6.9.420.309496/ja_JP/FILENAME.txt \
  --start-line START_LINE \
  --end-line END_LINE \
  --verbose
```
**Expected Output**: `Total issues found: 0`

### 3. Manual Verification
```bash
# Verify NO Japanese characters in action markers
grep -nP '::[^:]*[\p{Hiragana}\p{Katakana}\p{Han}][^:]*::' TARGET_FILE
# Expected: No output (empty result)

# Count translation rate
# (Total entries - Untranslated) / Total entries should be ~95%+
```

---

## Detailed Issue Lists

### Action Marker Issues (Full List)

See `translation/quality_issues_detailed.txt` lines 1-65 for complete list.

**Quick Reference**:
- Lines 199836, 200364, 200420, 201524: Individual action markers
- Lines 220164, 220166, 220168, 220228: Radio static markers (`::雑音::`)
- Lines 221324, 221372: Noise markers (`::ノイズ::`)
- Lines 223384, 223470, 224332: Action markers (snorts, nods, yawns)

### Untranslated Entry Issues (Full List)

See `translation/quality_issues_detailed.txt` lines 67+ for complete list (6,984 entries).

**Major Sections**:
- Lines 390-392: Ananda Rabindranath (2 entries)
- Lines 1462-1482: Asphalt G / Carla dialogue (~10 entries)
- Lines 4362-4516+: Elijah Ward dialogue (100+ entries)
- Additional 6,800+ entries throughout the file

---

## Recommendations

### Immediate Actions (TODAY)

1. ✅ **Complete quality scan** - DONE (7,004 issues identified)
2. ⬜ **Fix all action markers** (Phase 1) - 30-60 minutes
3. ⬜ **Implement automated validation** (Phase 3) - 1 hour
4. ⬜ **Begin untranslated entry fixes** (Phase 2) - Start first batch (100 entries)

### Short-term Actions (THIS WEEK)

1. ⬜ **Complete untranslated entry fixes** - Process ~700-1,000 entries per day
2. ⬜ **Update documentation** - Add validation requirements to all workflow docs
3. ⬜ **Create root cause analysis document** - Detailed lessons learned

### Long-term Improvements

1. **Workflow Enhancement**:
   - Add mandatory dual validation to all commit workflows
   - Update automation scripts to include quality checks
   - Create visual diff tool for translation review

2. **Documentation Updates**:
   - Add action marker examples to `CRITICAL_RULES.md`
   - Update Spanish reference logic in `STRICT_TRANSLATION_RULES.md`
   - Create troubleshooting guide for common errors

3. **Quality Assurance**:
   - Run full validation scan weekly
   - Track translation quality metrics (action marker errors, untranslated rate)
   - Create automated reporting dashboard

---

## Conclusion

The identified issues are critical but fixable:

- **Action markers**: Small scope (10 lines), high impact, immediate fix required (~30-60 min)
- **Untranslated entries**: Large scope (6,984 entries), high impact, systematic fix required (~20-30 hours)

**Estimated Total Fix Time**:
- Action markers: 30-60 minutes
- Untranslated entries: 20-30 hours (distributed over multiple sessions, ~100 entries per session)
- Automation: 1 hour

**Current Translation Quality**:
- **Actual translated**: ~8,781 entries (15,765 - 6,984)
- **Translation rate**: ~55.7% (should be 95%+)
- **Critical errors**: 20 action marker issues

**Recommended Approach**:
1. Fix action markers immediately (low effort, high value) - Phase 1
2. Set up automated validation (prevent future issues) - Phase 3
3. Fix untranslated entries in batches (systematic, tracked progress) - Phase 2

With proper validation in place (BOTH scripts mandatory before commit), these issues will not recur.

---

## Next Steps

1. ✅ **Problem investigation complete** - 7,004 issues identified
2. ⬜ **Fix action markers** - Start immediately (Phase 1)
3. ⬜ **Implement validation automation** - Complete today (Phase 3)
4. ⬜ **Begin untranslated fixes** - Start first batch today (Phase 2)
5. ⬜ **Document lessons learned** - Create root cause analysis
6. ⬜ **Update workflow documentation** - Add validation requirements
