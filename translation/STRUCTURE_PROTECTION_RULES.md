# Structure Protection Rules

**Version:** 2.0 (English version for AI - 2025-11-01)
**Primary Document:** See [CLAUDE.md](../CLAUDE.md) for complete guidelines

---

## ⚠️ IMPORTANT: Primary Reference

**This document is supplementary. The PRIMARY reference is [CLAUDE.md](../CLAUDE.md).**

For AI translation work, **ALWAYS refer to CLAUDE.md first**.

---

## Purpose

This document defines strict rules for protecting Unity StringTable file structure. Violating these rules makes files unable to import into the game.

---

## Protected Markers - NEVER MODIFY

### 1. Unity Structure Markers (Highest Priority)

#### `""` (Double Double-Quotes)

**Format:** Text must be wrapped in TWO double-quote characters at start and end.

```
string data = ""Japanese text here""
              ↑↑              ↑↑
              12              34
```

**Quote positions:**
1. Position 1: Outer string delimiter (half-width `"`)
2. Position 2: Inner text boundary marker (half-width `"`)
3. Position 3: Inner text boundary marker (half-width `"`)
4. Position 4: Outer string delimiter (half-width `"`)

**Examples:**

```
✅ CORRECT: string data = ""Hello, cowboy.""
            (4 half-width quotes: 2 before, 2 after)

❌ WRONG: string data = "「Hello, cowboy.」"
          (Japanese brackets)

❌ WRONG: string data = ""Hello, cowboy.""
          (Full-width quotes)

❌ WRONG: string data = "\"Hello, cowboy.\""
          (Backslash escaping - FORBIDDEN!)

❌ WRONG: string data = "'Hello, cowboy.'"
          (Single quotes)
```

**⚠️ Quote Escaping is ABSOLUTELY FORBIDDEN:**

Unity StringTable format does NOT use backslash (`\`) escaping for quotes. Never use `\"` - it breaks the structure. Always use `""` (two half-width double-quotes).

---

### 2. Game Variable Markers `[...]`

**Purpose:** Dynamic game content replacement

**Examples:**
```
[Switch to 27.065 Megahertz]
[Global: PlayerName]
[Dropset: RewardItems]
[Reward: 100]
```

**Rules:**
- ❌ NEVER translate content inside brackets
- ❌ NEVER change brackets to `【】` or other characters
- ✅ ALWAYS keep exact English text and format

---

### 3. HTML Tags `<...>`

**Purpose:** Text formatting (italic, bold, etc.)

**Examples:**
```
<i>italic text</i>
<b>bold text</b>
```

**Rules:**
- ❌ NEVER remove tags
- ❌ NEVER change tag names
- ✅ Translate text BETWEEN tags only
- ✅ Keep tag structure exactly as-is

---

### 4. Action Markers `::action::`

**Purpose:** Game engine control commands for animations, sounds, effects

**CRITICAL:** This is the most commonly violated rule (97 violations found 2025-11-01)

**Examples of action markers:**
```
::sigh::
::laughs::
::nods::
::static::
::gunfire::
::music plays::
::classic rock plays::
```

**ABSOLUTE RULES:**

```
❌ NEVER translate:
::sigh::  → ::ため息::        (translating to Japanese)
::laughs:: → ::笑う::         (translating to Japanese)
::classic rock plays:: → ::クラシックロック曲が流れる::

✅ ALWAYS keep in English:
English: string data = "::sigh:: "I don't know...""
Japanese: string data = "::sigh:: "わからない...""
                        ^^^^^^^^ UNCHANGED
```

**Why this is critical:**
- Translated action markers break game engine recognition
- Character animations will not play
- Sound effects will not trigger
- Visual effects will fail

**Verification command:**
```bash
# Should return nothing (no Japanese in action markers)
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
```

**See:** CLAUDE.md Section 5 for detailed action marker rules.

---

### 5. Technical Identifiers

**NEVER translate these:**

| Pattern | Example | Purpose |
|---------|---------|---------|
| `Script Node [number]` | `Script Node 14` | Game script reference |
| `[Switch to ...]` | `[Switch to 27.065 Megahertz]` | Radio frequency |
| `[Global: ...]` | `[Global: PlayerName]` | Global variable |
| `[Dropset: ...]` | `[Dropset: AmmoRewards]` | Item drop configuration |
| `[Reward: ...]` | `[Reward: 500]` | Reward value |
| `DEBUG` | `DEBUG - go to combat` | Debug message |

---

## Quote Count Matching - MANDATORY

**Rule:** Japanese translation must have SAME number of quotes as English source.

### Pattern A: 2 Quotes (Simple Text)

```
English:  string data = "Script Node 65"
Japanese: string data = "Script Node 65"
                        ↑              ↑
                        1 quote before, 1 quote after
```

### Pattern B: 4 Quotes (Quoted Dialogue)

```
English:  string data = ""Hello, Rangers.""
Japanese: string data = ""こんにちは、レンジャーズ。""
                        ↑↑                ↑↑
                        2 quotes before, 2 quotes after
```

### Pattern C: 6+ Quotes (Complex)

```
English:  string data = "::static:: "Come in..." ::static::"
Japanese: string data = "::static:: "応答せよ..." ::static::"
                        ↑          ↑          ↑            ↑
                        Must match source quote count exactly
```

**Validation:** `validate_structure_v2.py` checks quote count per line.

---

## Forbidden Characters and Patterns

### ❌ NEVER Use These:

1. **Japanese Brackets:**
   - `「」` (corner brackets)
   - `『』` (double corner brackets)
   - These break Unity StringTable format

2. **Full-Width Quotes:**
   - `""` (full-width double quotes)
   - `''` (full-width single quotes)
   - Only half-width quotes allowed

3. **Backslash Escaping:**
   - `\"` (quote escaping)
   - `\\` (backslash escaping)
   - Unity format doesn't use these

4. **Modified Brackets:**
   - `【】` (black lenticular brackets)
   - `[]` can ONLY be half-width ASCII

5. **Modified Tags:**
   - `＜i＞` (full-width angle brackets)
   - Only half-width `<>` allowed

---

## Text Control Characters - PRESERVE

### ✅ KEEP These Escape Sequences:

```
\n  - Newline
\r  - Carriage return
\t  - Tab
\\  - Backslash (in text content, not for quote escaping)
```

**Example:**
```
English:  string data = ""Line 1\nLine 2\n\nLine 4""
Japanese: string data = ""1行目\n2行目\n\n4行目""
                                 ↑↑    ↑↑
                                 Preserve \n exactly
```

---

## Validation Commands

### Structure Validation:
```bash
python3 translation/validate_structure_v2.py TARGET_FILE \
  --source SOURCE_FILE --detailed
```

**Checks:**
- Line count matching
- Quote count per line
- Game variable preservation
- HTML tag preservation
- NO Japanese brackets in structure

### Quality Validation:
```bash
python3 translation/validate_translation_quality.py TARGET_FILE \
  --start-line START --end-line END
```

**Checks:**
- NO Japanese in action markers
- NO untranslated entries (where Spanish shows translation)
- Technical terms preserved

### Manual Verification:
```bash
# Check for Japanese in action markers
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE

# Check for Japanese brackets (should return nothing)
grep '[「」『』]' TARGET_FILE

# Check for full-width quotes (should return nothing)
grep '[""'']' TARGET_FILE
```

---

## Common Mistakes and Fixes

### Mistake 1: Translating Action Markers
```
❌ WRONG: string data = "::ため息:: "わからない...""
✅ CORRECT: string data = "::sigh:: "わからない...""
```

### Mistake 2: Using Japanese Brackets
```
❌ WRONG: string data = "「こんにちは」"
✅ CORRECT: string data = ""こんにちは""
```

### Mistake 3: Quote Escaping
```
❌ WRONG: string data = "\"こんにちは\""
✅ CORRECT: string data = ""こんにちは""
```

### Mistake 4: Translating Game Variables
```
❌ WRONG: string data = "[27.065メガヘルツに切り替え]"
✅ CORRECT: string data = "[Switch to 27.065 Megahertz]"
```

### Mistake 5: Removing HTML Tags
```
❌ WRONG: string data = ""強調されたテキスト""
✅ CORRECT: string data = ""<i>強調されたテキスト</i>""
```

---

## Emergency Checklist

**Before committing, verify:**

- [ ] Line count matches source exactly
- [ ] All action markers (`::...:`) remain in English
- [ ] No Japanese brackets (`「」『』`) anywhere
- [ ] No full-width quotes (`""''`) anywhere
- [ ] No backslash quote escaping (`\"`)
- [ ] Game variables (`[...]`) unchanged
- [ ] HTML tags (`<...>`) preserved
- [ ] Quote count per line matches source
- [ ] Both validation scripts show 0 errors/issues

**If ANY item fails → STOP → Fix → Re-validate**

---

## Related Documentation

**Primary:**
- [CLAUDE.md](../CLAUDE.md) - Main translation guidelines

**Supplementary:**
- [STRICT_TRANSLATION_RULES.md](STRICT_TRANSLATION_RULES.md) - Translation rules summary
- [RETRANSLATION_WORKFLOW.md](RETRANSLATION_WORKFLOW.md) - Workflow guide

**Human-Readable (Japanese):**
- [CRITICAL_RULES.md](CRITICAL_RULES.md) - 絶対厳守ルール

**Tools:**
- `validate_structure_v2.py` - Structure validation
- `validate_translation_quality.py` - Quality validation

---

**Last Updated:** 2025-11-01
**Primary Reference:** [CLAUDE.md](../CLAUDE.md)
