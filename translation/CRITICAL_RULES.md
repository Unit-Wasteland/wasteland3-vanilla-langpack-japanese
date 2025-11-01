# CRITICAL TRANSLATION RULES - ZERO TOLERANCE

**Version**: 2.0
**Date**: 2025-11-01
**Status**: MANDATORY - NO EXCEPTIONS

---

## ⚠️ ABSOLUTE PROHIBITIONS

### 1. Action Markers Must NEVER Be Translated

**Format**: `::action::`

**Examples**: `::sniffs::`, `::static::`, `::nods::`, `::yawns::`, `::shivers::`

#### ❌ ABSOLUTELY FORBIDDEN:
```
::sniffs::  →  ::嗅ぐ::        ❌ WRONG
::static::  →  ::雑音::        ❌ WRONG
::nods::    →  ::頷く::        ❌ WRONG
::yawns::   →  ::あくびをする::  ❌ WRONG
```

#### ✅ CORRECT USAGE:
```
English: string data = "::sniffs:: "What's that smell?""
Spanish: string data = "::sniffs:: "¿Qué es ese olor?""
Japanese: string data = "::sniffs:: "何の臭いだ?""
                        ^^^^^^^^^ KEEP IN ENGLISH
```

**WHY**: Game engine control commands. Japanese text = broken animations/sounds/effects.

**VALIDATION**: Before commit, run:
```bash
grep -nP '::[^:]*[\p{Hiragana}\p{Katakana}\p{Han}][^:]*::' TARGET_FILE
# Expected: NO OUTPUT (empty result = correct)
```

---

### 2. Spanish Empty ≠ Skip Translation

**Spanish Reference Decision Tree**:

| Spanish | English | Action | Reason |
|---------|---------|--------|--------|
| `""` (empty) | `""` (empty) | ✅ Skip | Truly empty entry |
| `""` (empty) | `"TEXT"` | ✅ **Keep English** | Program identifier/technical term |
| `"TRANSLATED"` | `"TEXT"` | ✅ **Translate to Japanese** | Normal translatable text |

#### ❌ WRONG LOGIC:
```python
if Spanish == "":
    skip_translation()  # ❌ Leaves English untranslated
```

#### ✅ CORRECT LOGIC:
```python
if Spanish == "" AND English == "":
    skip()  # Truly empty
elif Spanish == "" AND English != "":
    keep_english()  # Program identifier (Script Node, DEBUG, etc.)
elif Spanish != "" AND Spanish != English:
    translate_to_japanese()  # Normal translatable text
```

---

### 3. Technical Terms - DO NOT TRANSLATE

| Term | Example | Action |
|------|---------|--------|
| `Script Node` | `Script Node 42` | ✅ Keep English |
| `DEBUG` | `DEBUG - go to combat` | ✅ Keep English |
| `[Global:` | `[Global: G_Variable]` | ✅ Keep English |
| `[Dropset:` | `[Dropset: Weapons]` | ✅ Keep English |
| `[Reward:` | `[Reward: 100]` | ✅ Keep English |
| `[Switch to` | `[Switch to 27.065 Megahertz]` | ✅ Keep English |

**Reference**: `translation/nouns_glossary.json` → `"do_not_translate"` section

---

## 🔒 MANDATORY VALIDATION (BEFORE EVERY COMMIT)

### Validation #1: Structure
```bash
python3 translation/validate_structure_v2.py TARGET_FILE \
  --source SOURCE_FILE --detailed
```
**Expected Output**: `Total errors: 0`

### Validation #2: Quality
```bash
python3 translation/validate_translation_quality.py TARGET_FILE \
  --start-line START_LINE --end-line END_LINE --verbose
```
**Expected Output**: `Total issues found: 0`

### Validation #3: Manual Check
```bash
# Check for Japanese in action markers
grep -nP '::[^:]*[\p{Hiragana}\p{Katakana}\p{Han}][^:]*::' TARGET_FILE
# Expected: NO OUTPUT

# Count translation rate
# (Actual Japanese entries) / (Total entries) should be ~95%+
```

---

## 📊 Quality Metrics (Track Per Session)

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Translation rate | ≥ 95% | Japanese entries / Total entries |
| Action marker errors | 0 | Quality validation report |
| Structure errors | 0 | Structure validation report |
| Untranslated entries | < 5% | Quality validation report |

---

## 🚨 If Validation Fails

1. **DO NOT COMMIT**
2. Review error/issue report
3. Fix problems one by one
4. Re-run BOTH validations
5. Only commit when BOTH show 0 errors/issues

---

## 📝 Common Action Markers (Reference)

### Emotions
- `::sigh::`, `::big sigh::` - ため息（keep English）
- `::laughs::`, `::chuckles::` - 笑い（keep English）
- `::cries::`, `::sobs::` - 泣く（keep English）
- `::screams::`, `::shouts::` - 叫ぶ（keep English）
- `::whispers::` - 囁く（keep English）

### Actions
- `::nods::` - 頷く（keep English）
- `::shrugs::` - 肩をすくめる（keep English）
- `::shivers::` - 震える（keep English）
- `::sniffs::` - 嗅ぐ（keep English）
- `::snorts::` - 鼻を鳴らす（keep English）
- `::yawns::` - あくびをする（keep English）

### Sounds
- `::static::` - 雑音/ノイズ（keep English）
- `::gunfire::` - 銃声（keep English）
- `::beep::` - ビープ音（keep English）

### Music
- `::classic rock plays::` - クラシックロック曲が流れる（keep English）
- `::rock ballad plays::` - ロックバラードが流れる（keep English）
- `::folk song plays::` - フォークソングが流れる（keep English）

**CRITICAL**: All action markers must remain in English, character-for-character.

---

## 📖 Related Documentation

- `translation/STRICT_TRANSLATION_RULES.md` - Comprehensive workflow guide
- `translation/STRUCTURE_PROTECTION_RULES.md` - Structure protection rules
- `translation/RETRANSLATION_WORKFLOW.md` - Retranslation process
- `translation/nouns_glossary.json` - Translation glossary
- `translation/ROOT_CAUSE_ANALYSIS.md` - Quality issue analysis (Japanese)
- `translation/quality_issues_report.md` - Latest quality report (English)

---

**Last Updated**: 2025-11-01
**Enforcement**: MANDATORY - All commits must comply
**Violations**: Will require immediate rollback and fix
