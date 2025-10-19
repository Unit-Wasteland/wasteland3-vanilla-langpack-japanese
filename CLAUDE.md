# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Japanese language pack translation project for Wasteland 3, a post-apocalyptic RPG game. The repository contains Unity StringTable data files extracted from the game that need to be translated from English (en_US) to Japanese (ja_JP).

### 🤖 Automated Translation System

This project features a **fully automated translation system** that can run unattended for days/weeks:

**Key Components:**
- **Automation Scripts**: `automation/auto-translate.sh` (Bash) and `automation/auto-translate.ps1` (PowerShell)
- **Progress Persistence**: `translation/.translation_progress.json` automatically tracks progress
- **Direct Translation**: Main Claude Code session performs translation work (no subagent overhead)
- **Memory Management**: Automatic session restart when memory reaches 6-7GB threshold

**Usage Modes:**
1. **Fully Automated** (Recommended for bulk translation):
   ```bash
   ./automation/auto-translate.sh  # Runs unattended until completion
   ```

2. **Manual Session** (For targeted translation or testing):
   ```bash
   claude
   # Then: "translation/.translation_progress.json を読み込んで、CLAUDE.mdのルールに従って翻訳作業を継続してください。"
   ```

See [`automation/README.md`](automation/README.md) for detailed automation documentation.

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
└── nouns_glossary.json       # Glossary for consistent noun translations (location: translation/nouns_glossary.json)
```

## File Format

The StringTable files use Unity's serialized text format with the following structure:

- **MonoBehaviour metadata** (lines 1-9): Header information
- **StringTable arrays**: Organized by mission/dialogue files
  - `Filename`: Mission or dialogue identifier (e.g., "mission_c1000_littlehell")
  - `entryIDs`: Array of integer IDs for each text entry
  - `femaleTexts`: Array of female-specific dialogue variants (often empty)
  - `defaultTexts`: Array of default/male dialogue text (main content)

**Important**: The `string data` lines contain the actual translatable text. Empty strings (`string data = ""`) should remain empty unless they need gender-specific translations.

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

4. **Format Preservation**
   - **Preserve structure**: Only modify text within `string data = "..."` fields
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

### Translation Execution Strategy - Direct Translation in Main Session

⚠️ **IMPORTANT: Translation work is performed directly in the main Claude Code session**

**Why direct translation (not subagent):**
1. **Permission handling**: Subagents require manual permission approval for file edits, which blocks automation
2. **Automation compatibility**: Direct translation enables fully unattended automated execution
3. **Memory management**: Strict chunking and commit strategies prevent memory issues
4. **Simplified workflow**: No coordination overhead between main session and subagent

**Key principles for automated translation:**
- **Strict memory management**: Process in 100-200 line chunks, commit every 1000 entries
- **Sequential processing**: Never batch operations that can be done sequentially
- **Frequent commits**: Regular commits reduce memory pressure and enable recovery
- **Session restarts**: Automated scripts handle session restarts when memory threshold reached

**Translation workflow:**
1. Read progress from `translation/.translation_progress.json`
2. Process translation in small chunks (100-200 lines per Read/Edit operation)
3. Reference `translation/nouns_glossary.json` for consistent terminology
4. Commit every 1000 entries to reduce memory pressure
5. Update progress file after each major milestone
6. Continue until target entry count reached or file completed

**For manual translation sessions:**
When user requests translation manually (not via automation script):
- Process in 100-200 line chunks
- Commit every 1000 entries or after major sections
- Reference glossary for all proper nouns
- Update progress file regularly
- Monitor memory usage and restart session if approaching 6-7GB

**For automated translation:**
The `automation/auto-translate.sh` script handles:
- Session memory monitoring and automatic restart
- Progress tracking across multiple sessions
- Error detection (3 consecutive sessions with 0 entries = stop)
- Logging to `automation/translation-automation.log`

### Translation Workflow Steps

**Step 1: Glossary Setup**
- Use the existing glossary at `translation/nouns_glossary.json`
- **CRITICAL**: Use ONLY `translation/nouns_glossary.json` - do NOT create additional glossary files
- The glossary is organized into categories: organizations_factions, characters, locations, etc.
- Check the `do_not_translate` section for terms that must NEVER be translated
- When encountering new proper nouns, add them to the appropriate category in the existing glossary

**Step 2: Sequential Translation**
- Start from line 1 of the first file (or resume from progress file)
- Translate each `string data` field in order
- Process in 100-200 line chunks (Read → Translate → Edit → Verify)
- Reference glossary for all proper nouns
- Commit every 1000 entries
- Verify format preservation after each section
- Move to next file only after completing current file

**Step 3: Quality Check**
- Verify no Simplified Chinese characters
- Verify line counts match exactly between source and target
- Verify all proper nouns use glossary translations
- Verify no structural changes
- Check git diff for any unexpected modifications

## Working with Large Files

The files are very large (530K+ lines). When editing:
- Use Read tool with offset and limit parameters to work in sections
- Use grep to locate specific dialogue or missions
- Edit specific string data lines rather than replacing entire files
- Test changes by comparing line counts before and after edits

## Memory Management - CRITICAL for Large File Processing

⚠️ **MANDATORY: Prevent Node.js Heap Out of Memory Errors**

When processing large translation files (530K+ lines), Node.js can run out of memory and crash. Follow these rules STRICTLY:

**IMPORTANT**: Translation work is performed directly in the main session (see "Translation Execution Strategy" section above). Strict memory management is essential for successful completion.

### Session Memory Management

⚠️ **CRITICAL FINDING**: The main Claude Code session's memory grows continuously because:
- Translation progress data accumulates in session history
- File read/edit operations build up in memory
- Large files require significant heap space

**Solution: Periodic Session Restart**

1. **Monitor main session memory** every 2,000-3,000 entries:
   ```bash
   ps aux | grep claude | awk '{print $6/1024 " MB"}'
   ```

2. **Session restart threshold**: When memory reaches **6-7 GB**, restart the session:
   - Current progress is automatically saved to `translation/.translation_progress.json`
   - Exit current Claude Code session
   - Start new Claude Code session
   - Resume with: `translation/.translation_progress.json を読み込んで、CLAUDE.mdのルールに従って翻訳作業を継続してください。`

3. **Progress state file**: `translation/.translation_progress.json`
   - Updated automatically after each major milestone (commit points)
   - Contains: last completed section, total entries, next action, git commit hash
   - Enables seamless continuation across session restarts

4. **Automated resume instructions**: See `translation/RESUME_TRANSLATION.md`

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

1. **Chunk Processing (MANDATORY)**
   - **CRITICAL**: Process files in SMALL chunks (100-200 lines at a time, NEVER exceed 300 lines)
   - **Chunk size reduction after OOM**: If out of memory occurred, reduce to 50-100 lines
   - Complete one chunk, then clear variables before moving to next chunk
   - NEVER load entire 530K line files into memory at once
   - Use Read tool with `offset` and `limit` parameters
   - **Between chunks**: Allow garbage collection to run by processing sequentially, not in batches

2. **Node.js Heap Size Configuration**
   - If running Node.js scripts, set heap size explicitly:
     ```bash
     node --max-old-space-size=4096 script.js  # 4GB heap
     node --max-old-space-size=8192 script.js  # 8GB heap (if available)
     ```
   - Default heap size (1.4GB) is insufficient for large files

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

2. **Restart with smaller chunks**
   - Reduce chunk size to 50-100 lines instead of 500
   - Process one mission section at a time

3. **Monitor memory during retry**
   - Keep track of memory usage percentage
   - If approaching 80%, commit current work and restart

4. **Save frequently**
   - **CRITICAL**: Commit translations every 1000 lines (or after each major mission section, whichever is smaller)
   - Don't wait until entire file is complete
   - Use descriptive commit messages noting progress (e.g., "Translate a1001_thepatriarch entries [0-49] (50 entries)")
   - After each commit, memory pressure is reduced for next chunk

### 4. Translation Task Execution Rules

**When performing translation in main session:**

1. **NEVER attempt to process entire files in one operation**
2. **ALWAYS use chunked approach**: Read → Translate → Edit → Verify → Repeat
3. **Maximum chunk size**: 100-200 lines per Read/Edit operation (NEVER exceed 300 lines)
   - **After OOM error**: Reduce to 50-100 lines per chunk
4. **Checkpoint frequency**: Commit every 1000 entries or every major mission section
5. **Memory check frequency**: Monitor after every 3-5 chunks (every ~500-1000 lines)
6. **Sequential processing**: Process one chunk at a time, never batch multiple chunks together
7. **Commit immediately**: After completing a checkpoint (1000 entries), commit before continuing
8. **Update progress file**: After each commit, update `translation/.translation_progress.json`

### 5. Signs of Memory Pressure

**STOP and clear memory if you observe:**
- Claude Code responses becoming slower
- Increased latency in tool execution
- Any garbage collection warnings in output
- Memory usage exceeding 80% of available heap

**Recovery action:**
- Commit current work immediately
- Clear all variables
- Restart translation from next checkpoint
- Reduce chunk size for remaining work

## Quality Checks

Before committing translations:
1. Verify line counts match between source and target files
2. Ensure array sizes remain unchanged
3. Check that entryIDs are identical between source and target
4. Validate that special formatting and variables are preserved
