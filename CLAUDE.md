# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️🔴 CRITICAL RULES - READ FIRST 🔴⚠️

**ABSOLUTE PROHIBITION - NO EXCEPTIONS:**

1. **NEVER create scripts for translation automation**
   - ❌ DO NOT create Python/Bash scripts to "batch process" translations
   - ❌ DO NOT suggest "efficiency improvements" via scripting
   - ❌ DO NOT write code to automate Read/Edit operations
   - ✅ ALWAYS translate manually using Read + Edit tools ONLY

2. **NEVER switch from manual to automated approach**
   - Even if facing 2,000+ untranslated entries
   - Even if user says "手動で継続してください" (continue manually)
   - Even if it seems "inefficient"
   - ✅ ALWAYS continue with 150-200 line chunk manual processing

3. **WHY THIS RULE EXISTS:**
   - Past automation attempts caused catastrophic structure destruction
   - Multiple complete project restarts due to script-induced errors
   - User has explicitly forbidden automation multiple times
   - Manual processing is the ONLY safe method

**BEFORE EVERY TRANSLATION ACTION, ASK YOURSELF:**
- Am I about to create a script? → STOP. Use Read/Edit instead.
- Am I thinking "this is inefficient"? → IGNORE. Continue manually.
- Did user say "manual"? → NEVER switch to automation.

**If you violate these rules, the entire project will require restart.**

---

## Project Overview

This is a Japanese language pack translation project for Wasteland 3, a post-apocalyptic RPG game. The repository contains Unity StringTable data files extracted from the game that need to be translated from English (en_US) to Japanese (ja_JP).

### 🔧 Current Task: Complete Retranslation with Strict Structure Protection (2nd Restart)

**IMPORTANT**: The project is in **strict retranslation mode** - complete restart (2nd time) with rigorous workflow.

**Restart Reason:** 77,533 structural errors (45.7% of entries) were discovered in the previous version. Unity StringTable structural markers (`""`) were incorrectly converted to Japanese brackets (`「」`, `『』`), or had quotes improperly added/removed, causing game import failures. The solution is a complete clean restart from English source with strict validation workflow.

**🔴 CRITICAL: Work Sequence - MANDATORY 🔴**

**YOU MUST follow this sequence strictly:**

1. **Base Game (169,712 entries)** - MUST reach 100% completion with strict validation
2. **DLC1: Battle of Steeltown (38,554 entries)** - Start ONLY after base game 100% complete
3. **DLC2: Cult of the Holy Detonation (24,152 entries)** - Start ONLY after DLC1 100% complete

**NEVER work on DLC1 or DLC2 until base game reaches 100% completion with validation.**

**Strict Retranslation Overview:**
- **Base**: English files (en_US) - guarantees correct structure (530,425 lines, 169,712 entries)
- **Reference**: Spanish files (es_ES) - MANDATORY for translatability judgment (NOT backup_broken)
- **Validation**: validate_structure_v2.py after EVERY edit - zero tolerance for errors
- **Protection**: Strict rules for `""`, `[]`, `<>`, `::action::` markers (no Japanese brackets allowed)
- **Scope**: 232,418 entries total (base game: 169,712 + DLC1: 38,554 + DLC2: 24,152)
- **Current Progress**: Base game 87.7% (148,757/169,712), **20,952 untranslated entries being auto-fixed**, DLC1 0% (not started), DLC2 0% (not started)
- **Current Task (2025-11-16)**: Automated fixing of 20,952 missed untranslated entries using auto-fix-untranslated.sh
- **Progress Tracking**: `translation/.retranslation_progress.json` v3.0
- **Approach**: Sequential from line 390, NO skipping/prioritization/batch processing

**Key Documents:**
- **translation/STRICT_TRANSLATION_RULES.md** - Comprehensive strict workflow guide (PRIMARY)
- **translation/STRUCTURE_PROTECTION_RULES.md** - Structure protection rules (detailed)
- **translation/RETRANSLATION_WORKFLOW.md** - Workflow overview
- **translation/validate_structure_v2.py** - Mandatory validation script

### 🤖 Automated Retranslation System

This project features a **fully automated retranslation system** with strict structure protection:

**Key Components:**
- **Automation Script**: `automation/auto-retranslate.sh` (NEW - for retranslation)
- **Permission Bypass**: Uses `--dangerously-skip-permissions` flag AND `yes` command for true unattended operation
  - `--dangerously-skip-permissions`: Bypasses internal Claude Code permission checks
  - `yes`: Automatically answers 'y' to interactive permission prompts
- **Exclusive Lock**: Prevents duplicate automation sessions (lock file: `automation/.retranslation.lock`)
  - Auto-removes stale locks from crashed sessions
  - Unlock utility: `./automation/auto-retranslate.sh --unlock` or `./automation/unlock-retranslation.sh`
- **Progress Persistence**: `translation/.retranslation_progress.json` automatically tracks progress
- **Direct Translation**: Main Claude Code session performs work (no subagent overhead)
- **Memory Management**: Optimized based on auto-translate.sh success pattern (REDESIGNED 2025-10-25)
  - **Root cause identified**: Small chunks (20 lines) caused ~90 Read/Edit operations → massive conversation history → JSON.stringify explosion at session end
  - **Solution**: Large chunks (150-200 lines) → ~10-15 operations (85% reduction) → small conversation history
  - Memory threshold: 5000MB (6GB physical RAM - 1GB margin)
  - Session memory monitoring: 30s intervals (adequate for large-chunk approach)
  - Session timeout: 60 minutes (ample time for 500 entries)
  - Automatic session restart when thresholds reached
- **High-Efficiency Architecture**: Based on proven auto-translate.sh design (NEW 2025-10-25)
  - **Session limit: 500 entries** (was 5 - 100x improvement)
  - **Chunk size: 150-200 lines** (was 20 - minimizes Read/Edit operations)
  - **Commit frequency: 500 entries** (was 5 - reduces git overhead)
  - **Simplified commands**: 15 lines (was 43 - reduces conversation bloat)
  - Expected completion: ~150 sessions (~3-4 days) vs old approach (~14,400 sessions, ~30-40 days)
- **Structure Protection**: Strict validation of `""`, `[]`, `<>`, `::action::` markers after every edit
- **Automatic Backup**: Automatic git push after each successful session (data loss prevention)
  - Pushes to remote only when progress is made
  - Detects and counts push failures (3 consecutive failures → abort)
  - Local commits are always safe, even if push fails
  - Minimizes data loss risk from server crashes or disk failures

**Usage Modes:**
1. **Fully Automated** (Recommended - runs until completion):
   ```bash
   ./automation/auto-retranslate.sh  # Runs unattended with structure protection
   ```

2. **Manual Session** (For testing or targeted work):
   ```bash
   claude
   # Current approach: Sequential processing from line 1
   # - Section 1 (lines 1-50,000): COMPLETE (5 dev messages deferred)
   # - Section 2 (lines 50,001-100,000): IN PROGRESS (50/342 translated)
   # Continue from line 51,540
   ```

3. **Unlock Stale Session** (If automation fails to start):
   ```bash
   ./automation/auto-retranslate.sh --unlock      # Safe unlock (recommended)
   ./automation/unlock-retranslation.sh           # Detailed unlock utility
   ./automation/unlock-retranslation.sh --force   # Force unlock (use with caution)
   ```

See `translation/RETRANSLATION_WORKFLOW.md` for detailed workflow documentation.

### 🔍 Automated Untranslated Entry Fixing System (NEW - 2025-11-16)

**Discovery (2025-11-16):** After completing base game translation to 87.7%, validation script improvements revealed **20,952 previously undetected untranslated entries**.

**Root Causes of Missed Entries:**
1. **Single-quote format blind spot**: Detection only supported `""content""` format, missing `"content"` format (~35,249 lines affected)
2. **Overly broad DEBUG exclusion**: All entries containing "DEBUG" were excluded, including legitimate game dialogue about computers/debugging
3. **Proper noun detection gap**: English proper nouns within Japanese text were not detected

**Validation Script Improvements:**
- **Dual-format support**: Now detects both `string data = ""content""` and `string data = "content"` formats
- **Refined exclusions**: Only exclude development messages (`^DEBUG -`, `^Test$`), not in-game dialogue
- **Proper noun detection**: Cross-reference nouns_glossary.json to detect untranslated proper nouns in Japanese text

**Automated Fixing Components:**

1. **generate-untranslated-list.sh**: Scans base game file and generates list of untranslated line numbers
   ```bash
   bash automation/generate-untranslated-list.sh
   # Outputs: automation/.untranslated_lines.txt (line numbers)
   #          automation/.untranslated_report.txt (detailed report)
   ```

2. **auto-fix-untranslated.sh**: Automated fixing via repeated Claude Code sessions
   - Processes 20 entries per session
   - Uses Read + Edit tools (strict CLAUDE.md compliance)
   - Memory monitoring (30s intervals, 5000MB limit)
   - Dual validation (structure + quality) after each batch
   - Auto git commit + push on success
   - 3 consecutive zero-fix sessions → stop (manual intervention required)
   - Expected completion: 3-7 days

3. **check-auto-fix-status.sh**: Monitor background process status
   ```bash
   bash automation/check-auto-fix-status.sh
   # Shows: PID, uptime, progress %, recent logs
   ```

**Usage (Background Execution):**
```bash
# Start auto-fix in background (protects current Claude Code session)
PROTECTED_CLAUDE_PID=$(pgrep claude | head -1) \
  nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &

# Check status from new Claude Code session
bash automation/check-auto-fix-status.sh

# Monitor real-time
tail -f automation/untranslated-fix-automation.log
```

**Process Independence:**
- Runs in background via `nohup` (survives session end)
- Uses separate Claude Code instance
- `PROTECTED_CLAUDE_PID` prevents killing interactive session
- Status checkable from any new Claude Code session

See `automation/README.md` and `automation/AUTO_FIX_README.md` for complete documentation.

## Repository Structure

```
translation/
├── source/                    # Source language files (reference)
│   └── v1.6.9.420.309496/    # Game version
│       ├── en_US/            # English source text (primary reference)
│       │   ├── StringTableData_English-CAB-*.txt  (530,425 lines - base game)
│       │   ├── DLC1/         # Battle of Steeltown DLC
│       │   │   └── StringTableData_English-CAB-*.txt  (120,559 lines)
│       │   └── DLC2/         # Cult of the Holy Detonation DLC
│       │       └── StringTableData_English-CAB-*.txt  (77,353 lines)
│       └── es_ES/            # Spanish files (MANDATORY for translatability judgment)
├── target/                    # Translation files (Japanese)
│   └── v1.6.9.420.309496/
│       └── ja_JP/            # Japanese translations (same structure as source)
├── backup_broken/            # Backup of broken format files (77,533 errors - NOT recommended for use)
│   ├── StringTableData_English-CAB-*.txt  (base game - 45.7% structural errors)
│   ├── DLC1/                 # DLC1 broken format backup
│   └── DLC2/                 # DLC2 broken format backup
├── nouns_glossary.json       # Glossary for consistent noun translations
├── .retranslation_progress.json  # Retranslation progress tracker (CURRENT)
├── .translation_progress.json    # Old translation progress (archived)
├── .format_fix_progress.json     # Old format fix progress (archived)
├── RETRANSLATION_WORKFLOW.md     # Detailed retranslation workflow guide
└── STRUCTURE_PROTECTION_RULES.md # Strict structure protection rules
```

## File Format

The StringTable files use Unity's serialized text format with the following structure:

- **MonoBehaviour metadata** (lines 1-9): Header information
- **StringTable arrays**: Organized by mission/dialogue files
  - `Filename`: Mission or dialogue identifier (e.g., "mission_c1000_littlehell")
  - `entryIDs`: Array of integer IDs for each text entry
  - `femaleTexts`: Array of female-specific dialogue variants (often empty)
  - `defaultTexts`: Array of default/male dialogue text (main content)

### ⚠️ CRITICAL: Unity StringTable Text Format

**The `string data` lines contain the actual translatable text with specific formatting:**

**Empty strings:**
```
string data = ""
```

**Text with content - TWO VALID FORMATS:**

Unity StringTable supports two quote formats depending on content type:

**Format 1: Simple text (2 quotes total - 1 at start, 1 at end):**
```
string data = "Simple Japanese text here"
```

**Format 2: Dialogue/embedded quotes (4 quotes total - 2 at start, 2 at end):**
```
string data = ""Japanese dialogue here""
```

**Format 3: Mixed narration with embedded dialogue (4 quotes total):**
```
string data = "Narration text. "embedded dialogue" more narration."
```

**CRITICAL RULE: Match English source quote count EXACTLY**
- If English has 2 quotes → Japanese must have 2 quotes
- If English has 4 quotes → Japanese must have 4 quotes
- Count all `"` characters in the line and match the source file precisely

**ABSOLUTELY FORBIDDEN - DO NOT USE:**
- ❌ Quote escape sequences: `string data = "\"Japanese text\""`  (NO backslash escaping for quotes!)
- ❌ Japanese brackets as structure: `string data = "「Japanese text」"` (brackets OK inside text, NOT as quote replacement)
- ❌ Full-width quotes: `string data = ""Japanese text""`
- ❌ Single quotes: `string data = "'Japanese text'"`
- ❌ Adding or removing quotes to change English source count

**ALLOWED - Text control characters:**
- ✅ Newline: `\n` (preserve as-is)
- ✅ Carriage return: `\r` (preserve as-is)
- ✅ Tab: `\t` (preserve as-is)
- ✅ Japanese brackets inside text content: `"彼女は言った。"こんにちは。"と答えた。"` (4 quotes, brackets inside)
- ✅ Other text formatting escape sequences within the text content

**Understanding Unity StringTable quote formats:**

Unity's StringTable format uses different quote counts for different content types:
- **2-quote format**: Used for simple text without embedded dialogue
  - Structure: `"text"`
  - Example: `string data = "Simple narration or description"`

- **4-quote format**: Used for dialogue or text with embedded quotes
  - Structure: `""dialogue""` OR `"text "embedded" text"`
  - Example 1: `string data = ""Character speech here""`
  - Example 2: `string data = "He said. "Hello." She replied."`

**Critical editing rule:**
1. First, check the English source line and COUNT the `"` characters
2. Translate the text content
3. Ensure Japanese line has EXACTLY the same number of `"` characters as English
4. NEVER add backslashes, NEVER change quote counts, NEVER use Japanese brackets `「」` as quote replacements

## Translation Workflow

1. **Source files** in `translation/source/v1.6.9.420.309496/en_US/` are READ-ONLY references
2. **Target files** in `translation/target/v1.6.9.420.309496/ja_JP/` contain the Japanese translations
3. Translations must preserve:
   - File structure and line count
   - Entry IDs and array indices
   - Special formatting markers (e.g., `[Switch to 27.065 Megahertz]`)
   - Variables and placeholders in the text

## Finding Translatable Text

Use grep to find lines with actual text content (non-empty strings):
```bash
grep -n 'string data = "[^"]\{1,\}"' <file.txt>
```

Count total lines in files:
```bash
wc -l translation/source/v1.6.9.420.309496/en_US/*.txt
wc -l translation/target/v1.6.9.420.309496/ja_JP/*.txt
```

## Translation Guidelines

### CRITICAL RULES - MUST FOLLOW

⚠️ **FILE FORMAT PRESERVATION IS MANDATORY**
- **NEVER add or remove lines** - The file must have EXACTLY the same line count as the source
- **NEVER modify structure** - Only change the text inside `string data = "..."` fields
- **Breaking the format will make the file unable to import into the game**, causing the translation to fail completely
- Always verify line counts match between source and target after any changes

### Translation Process Rules

1. **Sequential Translation (Most Important)**
   - Translate files **from top to bottom in order**
   - Do NOT skip lines or prioritize certain content
   - Do NOT jump to "important" dialogue or long texts first
   - **Complete each section sequentially before moving to the next**
   - This ensures completeness and prevents missing content

2. **Glossary Usage (nouns_glossary.json)**
   - **MUST create comprehensive glossary first** before starting translation
   - Extract all proper nouns from English source files:
     - Character names
     - Location names
     - Faction names
     - Item names
     - Technical terms
   - **Always reference glossary** to ensure consistent translations
   - Use the same Japanese translation for the same English term throughout

3. **Language Quality Control**
   - Use **Japanese (日本語) only** - NEVER use Simplified Chinese (简体中文) characters or expressions
   - Verify that all translations are natural Japanese appropriate for a post-apocalyptic RPG
   - Maintain consistent tone and style throughout the translation

4. **Format Preservation** ⚠️ CRITICAL

   **Structure Protection - NEVER do these:**
   - ❌ **NEVER use quote escape sequences**: `\"` is FORBIDDEN (Unity format doesn't need quote escaping)
   - ❌ **NEVER use Japanese brackets as quote replacements**: `「」` `『』` as structural quotes will break the file
   - ❌ **NEVER use full-width quotes**: `""` `''` are not valid
   - ❌ **NEVER add or remove quotes**: Always match English source quote count exactly
   - ❌ **NEVER translate structure markers**: Keep `[]`, `<>`, `::action::` exactly as-is
   - ✅ **DO preserve text control characters**: Keep `\n`, `\r`, `\t` within text content
   - ✅ **DO use Japanese brackets inside text**: `"彼女は「こんにちは」と言った。"` is valid (brackets inside, not replacing quotes)

   **Quote format rules (MANDATORY):**

   Unity StringTable uses TWO formats - always match the English source:

   **Format 1: Simple text (2 quotes)**
   ```
   string data = "Japanese text here"
                 ↑                  ↑
                 One " at start, one " at end (2 total)
   ```

   **Format 2: Dialogue/embedded quotes (4 quotes)**
   ```
   string data = ""Japanese dialogue here""
                 ↑↑                      ↑↑
                 Two " at start, two " at end (4 total)
   ```

   **Critical workflow:**
   1. Check English source line
   2. Count `"` characters in English (2 or 4)
   3. Translate text content
   4. Ensure Japanese has SAME number of `"` characters

   - **Preserve structure**: Only modify text within `string data = "..."` or `string data = ""...""`
   - **Maintain formatting**: Keep special markers like:
     - Radio frequencies: `[Switch to 27.065 Megahertz]`
     - Script nodes: `Script Node 14`
     - Technical annotations
     - Variables and placeholders in the text
   - **Gender variants**: Only populate `femaleTexts` if the source has different text; otherwise keep them empty
   - **Context**: The `Filename` field indicates the mission/dialogue context for better translation accuracy

5. **::action:: Markers - ABSOLUTELY CRITICAL** ⚠️🔴

   **ABSOLUTE RULES:** NEVER translate action markers (e.g., `::sigh::`, `::laughs::`, `::static::`). They control game animations/sounds and MUST remain in English.

   ⚠️ **MANDATORY: Post-Edit Verification**
   ```bash
   grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE  # Must return empty
   ```

6. **DO NOT TRANSLATE - Technical Terms** ⚠️
   - NEVER translate: `Script Node`, `[Global:]`, `[Switch to]`, etc.
   - Check `do_not_translate` in `translation/nouns_glossary.json` for complete list

7. **Translation Decision Logic** (Priority Order)
   1. Empty (`""`) → Skip
   2. In `do_not_translate` list → Keep English
   3. In `nouns_glossary.json` → Use glossary term
   4. Spanish translated AND differs from English → Translate
   5. **Otherwise → Translate** (default: prevents untranslated proper nouns)

8. **Space-Prefixed Entries - Special Handling** ⚠️ CRITICAL

   **IMPORTANT**: Entries that begin with a space character (` `) require careful evaluation. They are NOT always debug messages.

   **Evaluation Criteria - Check EACH entry individually:**

   **✅ TRANSLATE these space-prefixed entries:**
   - Game dialogue options: ` "Goodbye."`
   - Player choices: ` "What are we waiting for? Let's take the Bizarre."`
   - NPC responses: ` "Go on in. Asger and Bjorn will accompany you."`
   - Quest-related text: ` "Ready to begin assault on Bizarre."`
   - Game messages with technical comments: ` "Let the battle begin! (TODO Cutscene)"`
   - **Rule**: If the text contains actual in-game dialogue or player-facing content, TRANSLATE IT
   - **Preserve technical comments**: Keep `(TODO ...)`, `(Requires ...)`, `(quest active)` as-is in parentheses

   **❌ DO NOT TRANSLATE these space-prefixed entries:**
   - Variable assignments: ` "Set o2001_ToldFlabAboutCharleysPlan to 1"`
   - Debug menu options: ` "View Debug Options."`, ` "Select a Debug Option."`
   - System messages: ` "Global Variable set."`
   - Technical cascades: ` "Cascade 25"`, ` "Bank 31"`
   - Pure development markers: Starting with `DEBUG -`, `Test$`, `Set [variable]`, `Global Variable`
   - **Rule**: If the text is purely technical/system-level with no player-facing content, DO NOT TRANSLATE

   **Decision Process:**
   ```
   1. Read the space-prefixed entry
   2. Ask: "Would a player see this text in-game?"
      - YES → Translate (preserve technical comments in parentheses)
      - NO → Skip (pure debug/system message)
   3. When in doubt, check Spanish (es_ES) reference:
      - If Spanish translated it → Translate to Japanese
      - If Spanish kept it in English → Skip
   ```

   **Examples:**

   ✅ **TRANSLATE:**
   ```
   " Greetings. (Charley In Charge quest active)"
   → " 挨拶する。(Charley In Chargeクエストアクティブ時)"

   " Ready to begin assault on Bizarre."
   → " ビザール襲撃を開始する準備ができている。"

   " Can't start until the whole team is here!"
   → " チーム全員が揃うまで開始できない！"
   ```

   ❌ **DO NOT TRANSLATE:**
   ```
   " Set o2001_ToldFlabAboutCharleysPlan to 1"
   → Keep as-is (variable assignment)

   " View Debug Options."
   → Keep as-is (debug menu)

   " Global Variable set."
   → Keep as-is (system message)
   ```

   **Common Mistakes to Avoid:**
   - ❌ Translating ALL space-prefixed entries without checking
   - ❌ Skipping ALL space-prefixed entries without checking
   - ❌ Removing technical comments like `(TODO Cutscene)` during translation
   - ✅ Evaluating EACH entry based on whether it's player-facing content

### Retranslation Execution Strategy

**Key Principles:**
- **Sequential processing**: Start from line 390, complete each section 100% before moving
- **Chunk size**: 150-200 lines (minimizes Read/Edit operations)
- **Session limit**: 500 entries/session (~340 sessions total for base game)
- **Validation**: BOTH structure + quality validation after EVERY edit (zero tolerance)
- **Commits**: Every 500 entries
- **Memory**: 5000MB limit, monitored every 30s

**Workflow:**
1. Read progress → 2. Read chunks (150-200 lines) → 3. Apply translation decision logic → 4. Translate using glossary → 5. **Validate** (structure + quality, must pass ZERO errors) → 6. Commit every 500 entries → 7. End session

**Validation (MANDATORY after each edit):**
```bash
# Structure: python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_FILE --detailed
# Quality: python3 translation/validate_translation_quality.py TARGET_FILE --start-line X --end-line Y
# Both must show 0 errors. If fails: STOP, fix, re-validate
```

**For manual sessions:** Chunk size: 10-20 entries (fixes) or 150-200 lines (new). Validate after EVERY edit. Commit after batch. Sequential only.

**For automated:** `automation/auto-retranslate.sh` handles memory monitoring, progress tracking, dual validation, and auto-restart. See `automation/README.md`.

### Workflow Steps (Details in RETRANSLATION_WORKFLOW.md)

**Step 1:** Environment prep (one-time) - English files → target, init progress
**Step 2:** Sequential retranslation - 150-200 line chunks, validate, commit every 500 entries
**Step 3:** Validation (MANDATORY) - Structure + Quality scripts, both must show 0 errors before commit

## Working with Large Files

The files are very large (530K+ lines). When editing:
- Use Read tool with offset and limit parameters to work in sections
- Use grep to locate specific dialogue or missions
- Edit specific string data lines rather than replacing entire files
- Test changes by comparing line counts before and after edits

## Memory Management - CRITICAL for Large File Processing

⚠️ **MANDATORY: Prevent Node.js Heap Out of Memory Errors**

When processing large translation files (530K+ lines), Node.js can run out of memory and crash. Follow these rules STRICTLY:

**IMPORTANT**: Retranslation work is performed directly in the main session (see "Retranslation Execution Strategy" section above). Strict memory management is essential for successful completion.

### Session Memory Management

⚠️ **CRITICAL FINDING**: The main Claude Code session's memory grows continuously because:
- Retranslation progress data accumulates in session history
- File read/edit operations build up in memory
- Large files require significant heap space

**Solution: Periodic Session Restart**

1. **Monitor main session memory** every 2,000-3,000 entries:
   ```bash
   ps aux | grep claude | awk '{print $6/1024 " MB"}'
   ```

2. **Session restart threshold** (Optimized for 6GB RAM Ubuntu server - REDESIGNED 2025-10-25):
   - **5000MB (5GB)**: Memory limit - session terminates if exceeded
   - **30s monitoring interval**: Check memory every 30 seconds (adequate for large-chunk approach)
   - **No preemptive termination needed**: Large chunks (150-200 lines) prevent conversation history explosion
   - **Expected memory usage**: 1-2GB per session (well below limit) due to minimal Read/Edit operations
   - Node.js heap limit: 2.5GB (leaves ~3.5GB for OS and other processes)
   - Current progress is automatically saved to `translation/.retranslation_progress.json`
   - Automation script automatically starts new session after normal completion or timeout
   - Resume with retranslation command

3. **Progress state file**: `translation/.retranslation_progress.json`
   - Updated automatically after each major milestone (commit points)
   - Contains: current file, line offset, total entries, next action, git commit hash
   - Enables seamless continuation across session restarts

4. **Automated resume**: The `automation/auto-retranslate.sh` script handles automatic session restarts

### 1. Memory Monitoring Rules

**BEFORE starting any translation task:**
- Check Node.js memory usage regularly during processing
- **80% threshold rule**: If memory usage exceeds 80% of heap limit, STOP and clear memory
- Use the following to monitor memory (if available via Node.js script):
  ```javascript
  const used = process.memoryUsage();
  const heapUsedPercent = (used.heapUsed / used.heapTotal) * 100;
  if (heapUsedPercent > 80) {
    // Clear memory and use garbage collection
    global.gc && global.gc();
  }
  ```

### 2. Memory Management Best Practices

**ALWAYS follow these practices:**

1. **Chunk Processing (MANDATORY) - Redesigned based on auto-translate.sh (2025-10-25)**
   - **CRITICAL**: Process files in LARGE chunks (150-200 lines) to minimize Read/Edit operations
   - **Standard chunk size**: 150-200 lines (minimizes conversation history accumulation)
   - **Root cause understanding**: Small chunks (20 lines) caused ~90 operations/session → massive conversation history → JSON.stringify explosion
   - **Solution**: Large chunks → ~10-15 operations/session → small conversation history → no memory spikes
   - **Session entry limit**: 500 entries per session (high efficiency - 100x improvement)
   - Complete one chunk, then clear variables before moving to next chunk
   - NEVER load entire 530K line files into memory at once
   - Use Read tool with `offset` and `limit` parameters
   - **Between chunks**: Allow garbage collection to run by processing sequentially, not in batches

2. **Node.js Heap Size Configuration (6GB RAM Server)**
   - Automation script sets heap size to 2.5GB:
     ```bash
     node --max-old-space-size=2560  # 2.5GB heap (optimal for 6GB physical RAM)
     ```
   - Leaves ~3.5GB for OS and other processes
   - Default heap size (1.4GB) is insufficient for large files
   - 8GB heap would exceed physical RAM and cause swapping

3. **Manual Garbage Collection**
   - Between processing chunks, explicitly clear large variables
   - If possible, enable and trigger garbage collection:
     ```bash
     node --expose-gc script.js
     ```
   - Call `global.gc()` after processing each major section

4. **Section-based Translation Strategy**
   - Divide translation work by mission sections (using `Filename` field)
   - Complete one mission section, save, clear memory, then proceed to next
   - Each mission section is typically 50-500 lines, manageable size

### 3. Error Recovery Procedure

**If heap out of memory error occurs:**

1. **Identify last successfully processed line number**
   - Check git diff to see what was translated before crash
   - Note the last `Filename` section that was completed

2. **Restart with smaller chunks (6GB RAM)**
   - Use 20-line chunks (strict limit for 6GB server and CLI memory)
   - Process one mission section at a time

3. **Monitor memory during retry (6GB RAM - REDESIGNED 2025-10-25)**
   - Automated monitoring every 30 seconds
   - Session terminates at 5000MB (safety threshold - rarely reached with large chunks)

4. **Save efficiently (6GB RAM - REDESIGNED 2025-10-25)**
   - **Commit every 500 entries** (efficient git operations while maintaining safety)
   - Efficient commit frequency reduces git overhead
   - Don't wait until entire file is complete
   - Use descriptive commit messages noting progress (e.g., "Retranslation: base_game entries 1-500")
   - After each commit, memory pressure is reduced for next chunk
   - Update progress file after each commit
   - **End session after ~500 entries** (high efficiency - completes work in ~150 sessions total)

### 4. Translation Task Execution Rules (6GB RAM Optimized - REDESIGNED 2025-10-25)

**When performing any work in main session (translation or format fix):**

1. **NEVER attempt to process entire files in one operation**
2. **ALWAYS use chunked approach**: Read → Process → Edit → Verify → Repeat
3. **Chunk size**: 150-200 lines per Read/Edit operation (large chunks to minimize operations)
   - **Standard**: 150-200 lines (minimizes conversation history accumulation)
   - **Reasoning**: Large chunks → fewer operations → small conversation history → no JSON.stringify errors
4. **Session entry limit**: 500 entries per session (high efficiency - 100x improvement from old 5-entry limit)
5. **Checkpoint frequency**: Commit every 500 entries (efficient git operations)
6. **Memory check frequency**: Automated every 30 seconds (adequate for large-chunk approach)
7. **Sequential processing**: Process one chunk at a time, never batch multiple chunks together
8. **Commit immediately**: After completing a checkpoint, commit before continuing
9. **Update progress file**: After each commit, update the appropriate progress file
10. **End session**: After ~500 entries processed, end the session and restart

### 5. Signs of Memory Pressure (6GB RAM Server - REDESIGNED 2025-10-25)

**Expected behavior with new large-chunk architecture:**
- **Normal memory usage**: 1-2GB per session (well within limits)
- **No preemptive termination needed**: Conversation history stays small due to minimal Read/Edit operations
- **Safety threshold**: 5000MB - session terminates if exceeded (unlikely with large chunks)

**Manual indicators (if running manual session):**
- Claude Code responses becoming slower
- Increased latency in tool execution
- Any garbage collection warnings in output
- Memory usage consistently above 3GB (unusual - may indicate issue)

**Recovery action (automated):**
- Session terminates automatically at 5000MB threshold (safety net)
- Work is committed every 500 entries (maintains progress)
- Progress saved to .retranslation_progress.json
- Automation script restarts new session after 60s cooldown

**Note**: With the new architecture, memory issues should be rare. If they occur, it indicates a problem with the implementation rather than the approach.

## Quality Checks

Before committing translations:
1. Verify line counts match between source and target files
2. Ensure array sizes remain unchanged
3. Check that entryIDs are identical between source and target
4. Validate that special formatting and variables are preserved

---

## Related Documentation

For detailed information about the retranslation process:

- **`translation/RETRANSLATION_WORKFLOW.md`** - Complete retranslation workflow guide
  - Environment preparation steps
  - Detailed processing logic
  - Memory management strategy
  - Troubleshooting guide

- **`translation/STRUCTURE_PROTECTION_RULES.md`** - Strict structure protection rules
  - Comprehensive list of protected markers
  - Error examples and fixes
  - Validation patterns
  - Safety checklist

- **`translation/nouns_glossary.json`** - Translation glossary
  - Proper nouns (characters, locations, factions)
  - Technical terms
  - Do-not-translate list

- **`automation/README.md`** - Automation system documentation
  - Script usage
  - Security warnings
  - Monitoring and logging
