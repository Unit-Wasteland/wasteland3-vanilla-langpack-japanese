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
└── nouns_glossary.json       # Glossary for consistent noun translations
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

### Translation Workflow Steps

**Step 1: Glossary Creation**
- Read through English source files
- Extract all proper nouns and key terms
- Create `nouns_glossary.json` with English-Japanese mappings
- Format: `{"English Term": "日本語訳", ...}`

**Step 2: Sequential Translation**
- Start from line 1 of the first file
- Translate each `string data` field in order
- Reference glossary for all proper nouns
- Verify format preservation after each section
- Move to next file only after completing current file

**Step 3: Quality Check**
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

## Quality Checks

Before committing translations:
1. Verify line counts match between source and target files
2. Ensure array sizes remain unchanged
3. Check that entryIDs are identical between source and target
4. Validate that special formatting and variables are preserved
