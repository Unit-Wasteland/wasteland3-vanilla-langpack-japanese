# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Japanese language pack translation project for Wasteland 3, a post-apocalyptic RPG game. The repository contains Unity StringTable data files extracted from the game that need to be translated from English (en_US) to Japanese (ja_JP).

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
   - These are internal game engine references and translating them will break the game
   - Check the `do_not_translate` section in `translation/nouns_glossary.json` for the complete list
   - When in doubt, compare with the English source file - if it's identical in structure to technical terms, do NOT translate it

### Translation Execution Strategy - Use Subagent (MANDATORY)

⚠️ **CRITICAL: All translation work MUST be performed by the wasteland3-translator subagent**

**Why use subagent:**
1. **Token management**: Translation tasks consume large amounts of tokens. Using a subagent allows session switching when tokens run low
2. **Session continuity**: If main session runs out of tokens, you can start a new session and continue translation without losing progress
3. **Memory isolation**: Each subagent has its own memory space, preventing memory issues in the main session
4. **Specialized context**: The subagent maintains focused context on translation work only

**When to use the wasteland3-translator subagent:**
- ALL translation tasks (creating glossary, translating files, quality checks)
- When user requests: "翻訳してください", "翻訳を続けて", "translate", "continue translation"
- When working with StringTable files in translation/target/ directory
- When updating or creating nouns_glossary.json

**How to invoke the subagent:**

Use the Task tool with `subagent_type: "wasteland3-translator"`:

```
Task tool parameters:
- subagent_type: "wasteland3-translator"
- description: "Translate [file name] [section/line range]"
- prompt: "Detailed instructions for the translation task, including:
    - Specific file path to translate
    - Line range or section to work on (if applicable)
    - Current progress/checkpoint
    - Any specific instructions or context
    - Reference to CLAUDE.md guidelines"
```

**Example invocations:**

1. Starting new translation:
```
subagent_type: "wasteland3-translator"
description: "Translate CAB-12345.txt"
prompt: "Translate translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-12345.txt to Japanese. Follow all guidelines in CLAUDE.md. Start from line 1, process in chunks of 500 lines maximum. Save progress every 2000 lines."
```

2. Continuing translation:
```
subagent_type: "wasteland3-translator"
description: "Continue CAB-12345 from line 5000"
prompt: "Continue translating StringTableData_English-CAB-12345.txt from line 5000. Last completed section was 'mission_c2000_something'. Follow CLAUDE.md guidelines, process in 500-line chunks, commit every 2000 lines."
```

3. Creating/updating glossary:
```
subagent_type: "wasteland3-translator"
description: "Update nouns glossary"
prompt: "Update translation/nouns_glossary.json with new proper nouns found in [specific file or section]. Follow glossary structure and categorization rules in CLAUDE.md."
```

**Main session responsibilities:**
- Route translation requests to wasteland3-translator subagent
- Monitor overall progress
- Handle user questions about translation status
- Manage git operations (commits, branches) based on subagent reports
- Coordinate between multiple translation tasks if needed

**Subagent responsibilities:**
- Perform actual translation work
- Read source files and write target files
- Follow all translation guidelines in CLAUDE.md
- Manage memory by processing in chunks
- Report progress and completion status back to main session

### Translation Workflow Steps

**Step 1: Glossary Setup**
- **IMPORTANT**: Invoke wasteland3-translator subagent for glossary creation/updates
- Use the existing glossary at `translation/nouns_glossary.json`
- **CRITICAL**: Use ONLY `translation/nouns_glossary.json` - do NOT create additional glossary files
- The glossary is organized into categories: organizations_factions, characters, locations, etc.
- Check the `do_not_translate` section for terms that must NEVER be translated
- When encountering new proper nouns, add them to the appropriate category in the existing glossary

**Step 2: Sequential Translation**
- **IMPORTANT**: Invoke wasteland3-translator subagent for all translation work
- Subagent should start from line 1 of the first file
- Translate each `string data` field in order
- Reference glossary for all proper nouns
- Verify format preservation after each section
- Move to next file only after completing current file

**Step 3: Quality Check**
- **IMPORTANT**: Invoke wasteland3-translator subagent for quality verification
- Verify no Simplified Chinese characters
- Verify line counts match exactly
- Verify all proper nouns use glossary translations
- Verify no structural changes

## Working with Large Files

The files are very large (530K+ lines). When editing:
- Use Read tool with offset and limit parameters to work in sections
- Use grep to locate specific dialogue or missions
- Edit specific string data lines rather than replacing entire files
- Test changes by comparing line counts before and after edits

## Memory Management - CRITICAL for Large File Processing

⚠️ **MANDATORY: Prevent Node.js Heap Out of Memory Errors**

When processing large translation files (530K+ lines), Node.js can run out of memory and crash. Follow these rules STRICTLY:

**IMPORTANT**: All translation work should be performed by the wasteland3-translator subagent (see "Translation Execution Strategy" section above). This provides additional memory isolation and allows session continuity even if memory issues occur.

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
   - Process files in small chunks (100-500 lines at a time)
   - Complete one chunk, then clear variables before moving to next chunk
   - NEVER load entire 530K line files into memory at once
   - Use Read tool with `offset` and `limit` parameters

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
   - Commit translations after each major section (every 1000-2000 lines)
   - Don't wait until entire file is complete
   - Use descriptive commit messages noting progress (e.g., "lines 1-2000 of file X")

### 4. Translation Task Execution Rules

**When Claude Code performs translation:**

1. **NEVER attempt to process entire files in one operation**
2. **ALWAYS use chunked approach**: Read → Translate → Edit → Verify → Repeat
3. **Maximum chunk size**: 500 lines per Read/Edit operation
4. **Checkpoint frequency**: Save/commit every 2000 lines or every mission section
5. **Memory check frequency**: Monitor after every 5 chunks (every ~2500 lines)

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
