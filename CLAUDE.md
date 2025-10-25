# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Japanese language pack translation project for Wasteland 3, a post-apocalyptic RPG game. The repository contains Unity StringTable data files extracted from the game that need to be translated from English (en_US) to Japanese (ja_JP).

### 🔧 Current Task: Complete Retranslation with Structure Protection

**IMPORTANT**: The project is in **retranslation mode** - redoing all translations with strict structure protection.

Due to previous automation issues, Unity StringTable structural markers (`""`) were incorrectly converted to Japanese brackets (`「」`, `『』`), causing game import failures. The solution is to completely retranslate all files using English source as base, with strict structure protection.

**Retranslation Overview:**
- **Base**: English files (en_US) - guarantees correct structure
- **Reference**: backup_broken files - reuses existing Japanese translations where valid
- **Protection**: Strict rules for `""`, `[]`, `<>`, `::action::` markers
- **Scope**: 71,992 entries across base game + DLC1 + DLC2
- **Progress**: Tracked in `translation/.retranslation_progress.json`

See `translation/RETRANSLATION_WORKFLOW.md` for detailed workflow and `translation/STRUCTURE_PROTECTION_RULES.md` for structure rules.

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
   # Then: "translation/.retranslation_progress.json を読み込んで、translation/RETRANSLATION_WORKFLOW.md に従って翻訳やり直し作業を継続してください。"
   ```

3. **Unlock Stale Session** (If automation fails to start):
   ```bash
   ./automation/auto-retranslate.sh --unlock      # Safe unlock (recommended)
   ./automation/unlock-retranslation.sh           # Detailed unlock utility
   ./automation/unlock-retranslation.sh --force   # Force unlock (use with caution)
   ```

See `translation/RETRANSLATION_WORKFLOW.md` for detailed workflow documentation.

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
│       └── es_ES/            # Spanish files (may be useful for reference)
├── target/                    # Translation files (Japanese)
│   └── v1.6.9.420.309496/
│       └── ja_JP/            # Japanese translations (same structure as source)
├── backup_broken/            # Backup of broken format files (reference for retranslation)
│   ├── StringTableData_English-CAB-*.txt  (base game - broken format but useful Japanese text)
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

**Text with content (using DOUBLE double-quotes):**
```
string data = ""Japanese text here""
```

**ABSOLUTELY FORBIDDEN - DO NOT USE:**
- ❌ Quote escape sequences: `string data = "\"Japanese text\""`  (NO backslash escaping for quotes!)
- ❌ Japanese brackets: `string data = "「Japanese text」"`
- ❌ Full-width quotes: `string data = ""Japanese text""`
- ❌ Single quotes: `string data = "'Japanese text'"`

**ALLOWED - Text control characters:**
- ✅ Newline: `\n` (preserve as-is)
- ✅ Carriage return: `\r` (preserve as-is)
- ✅ Tab: `\t` (preserve as-is)
- ✅ Other text formatting escape sequences within the text content

**Why double double-quotes (`""`):**
Unity's StringTable format requires text to be wrapped in TWO double-quote characters at start and end. This is NOT an escape sequence - it's the literal format requirement. Think of it as:
- First `"` = string delimiter (Unity format)
- Second `"` = text boundary marker (Unity format)
- Your text goes here
- Third `"` = text boundary marker (Unity format)
- Fourth `"` = string delimiter (Unity format)

**Critical editing rule:**
When editing `string data` lines, ONLY modify the text between the inner double-quotes. NEVER add backslashes, NEVER change the `""` markers to any other character.

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
   - ❌ **NEVER change `""` to Japanese brackets**: `「」` `『』` will break the file
   - ❌ **NEVER use full-width quotes**: `""` `''` are not valid
   - ❌ **NEVER translate structure markers**: Keep `""`, `[]`, `<>`, `::action::` exactly as-is
   - ✅ **DO preserve text control characters**: Keep `\n`, `\r`, `\t` within text content

   **Correct format (MANDATORY):**
   ```
   string data = ""Japanese text here""
                 ↑↑              ↑↑
                 Two " at start, two " at end (4 total)
   ```

   - **Preserve structure**: Only modify text within `string data = ""...""`
   - **Maintain formatting**: Keep special markers like:
     - Radio frequencies: `[Switch to 27.065 Megahertz]`
     - Script nodes: `Script Node 14`
     - Technical annotations
     - Variables and placeholders in the text
   - **Gender variants**: Only populate `femaleTexts` if the source has different text; otherwise keep them empty
   - **Context**: The `Filename` field indicates the mission/dialogue context for better translation accuracy

5. **DO NOT TRANSLATE - Technical Terms** ⚠️
   - **ABSOLUTELY NEVER translate the following technical terms**:
     - `Script Node` (followed by any number) - This is a technical identifier, NOT dialogue
     - `Node` (when referring to script nodes)
     - Any text that starts with `Script Node` must remain in English
     - **Action markup in `::action::` format** (e.g., `::sings::`, `::laughs::`, `::coughs::`) - These are game engine processing markers for character actions and emotions
   - These are internal game engine references and translating them will break the game
   - **Action markup examples**: `::sings::`, `::laughs::`, `::coughs::`, `::whispers::`, `::shouts::`, etc. - Keep the double-colon format EXACTLY as is
   - Check the `do_not_translate` section in `translation/nouns_glossary.json` for the complete list
   - When in doubt, compare with the English source file - if it's identical in structure to technical terms, do NOT translate it

### Retranslation Execution Strategy - Direct Work in Main Session

⚠️ **IMPORTANT: Retranslation work is performed directly in the main Claude Code session**

**Why direct execution (not subagent):**
1. **Permission handling**: Subagents require manual permission approval for file edits, which blocks automation
2. **Automation compatibility**: Direct execution enables fully unattended automated operation
3. **Memory management**: Strict chunking and commit strategies prevent memory issues
4. **Simplified workflow**: No coordination overhead between main session and subagent

**Key principles for retranslation (REDESIGNED 2025-10-25 - based on auto-translate.sh):**
- **Large chunk processing**: Process in 150-200 line chunks (minimizes Read/Edit operations → small conversation history)
- **Session limit**: 500 entries per session (high efficiency - completes in ~150 sessions total)
- **Structure protection**: Validate `""`, `[]`, `<>`, `::action::` markers after EVERY edit
- **Sequential processing**: Never batch operations that can be done sequentially
- **Efficient commits**: Commit every 500 entries (reduces git overhead while maintaining safety)
- **Session restarts**: Automated scripts handle session restarts when memory threshold reached
- **Memory threshold**: 5000MB limit (6GB physical RAM - 1GB margin, monitored every 30s)

**Standard retranslation workflow (REDESIGNED 2025-10-25):**
1. Read progress from `translation/.retranslation_progress.json`
2. **Read 150-200 line chunks** from both backup_broken (Japanese source) and target (English base)
3. Extract Japanese text from backup_broken, apply to target with structure protection
4. For untranslated entries: translate English→Japanese using `nouns_glossary.json`
5. Validate structure after each edit (line count, markers, no Chinese characters)
6. **Commit every 500 entries** with progress update (efficient memory management)
7. **End session after ~500 entries** (high efficiency - minimizes total sessions needed)
8. Continue until all files completed (expected: ~150 sessions, ~3-4 days)

**For manual sessions (REDESIGNED 2025-10-25):**
When user requests work manually (not via automation script):
- **Chunk size**: 150-200 lines (large chunks to minimize Read/Edit operations)
- **Session target**: Process as many entries as comfortable (aim for 500 if possible)
- **Structure validation**: MANDATORY after each edit
- **Commit frequency**: 500 entries (or when completing a major section)
- Reference glossary for all proper nouns (translation only)
- Update progress file after each commit
- Memory threshold: 5000MB (6GB RAM - 1GB margin)

**For automated retranslation:**
The `automation/auto-retranslate.sh` script handles:
- Session memory monitoring and automatic restart
- Progress tracking across multiple sessions
- Error detection (3 consecutive sessions with 0 entries = stop)
- Logging to `automation/retranslation-automation.log`
- Structure validation after each commit

### Retranslation Workflow Steps

**Step 1: Environment Preparation** (one-time setup)
- Copy English files from `source/en_US/` to `target/ja_JP/` as new base
- Existing broken translations already backed up in `backup_broken/`
- Initialize progress file: `translation/.retranslation_progress.json`
- See `translation/RETRANSLATION_WORKFLOW.md` Phase 0 for details

**Step 2: Sequential Retranslation** (automated)
- Process files in order: base_game → DLC1 → DLC2
- For each 20-line chunk:
  1. Read backup_broken file (extract Japanese text)
  2. Read target file (English base with correct structure)
  3. Apply Japanese text with structure protection
  4. For untranslated entries: translate English→Japanese using glossary
  5. Validate structure markers (`""`, `[]`, `<>`, `::action::`)
  6. Edit target file with validated translation
- Commit every 10 entries with progress update
- End session after 15 entries (automatic restart by automation script)
- Continue until all 71,992 entries completed (across multiple sessions)

**Step 3: Quality Validation** (automatic per commit)
- Line count matches source (mandatory)
- No broken structure markers (no `「」` in structure)
- No Chinese characters mixed in
- All action markups remain English (`::action::`)
- Script Node not translated
- Git diff shows only text changes, no structure changes

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
