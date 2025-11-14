#!/usr/bin/env python3
"""
Accurate untranslated entry detection script for Wasteland 3 Japanese translation.

This script follows CLAUDE.md rules:
1. Checks do_not_translate list from nouns_glossary.json
2. Uses Spanish reference to determine if entry should be translated
3. Identifies entries where Japanese == English (untranslated)
4. Excludes technical markers, action-only entries, and empty strings
"""

import re
import json
import sys

def extract_string_data(line):
    """Extract content from 'string data = "..."' line"""
    match = re.search(r'string data = "((?:[^"\\]|\\.)*)"', line)
    if match:
        return match.group(1)
    return None

def load_glossary():
    """Load do_not_translate list from glossary"""
    try:
        with open('translation/nouns_glossary.json', 'r', encoding='utf-8') as f:
            glossary = json.load(f)
            return glossary.get('do_not_translate', [])
    except:
        return []

def should_not_translate(text, do_not_translate_list):
    """Check if text should NOT be translated based on rules"""
    if not text or text.strip() == "":
        return True

    # Check do_not_translate list
    for term in do_not_translate_list:
        if text.startswith(term):
            return True

    # Pure action markers only (no dialogue)
    if re.match(r'^::[^:]+::\s*$', text):
        return True

    # UI markers/game variables in brackets (even with spaces)
    if re.match(r'^\s*\[.+\]\s*$', text):
        return True

    # Code snippets (contain programming syntax)
    if re.search(r'(GetModule|ServerInstance|InternalVI|for\s*\(|if\s*\()', text):
        return True

    # Just whitespace or special chars
    if re.match(r'^[\s\n\r\t]+$', text):
        return True

    return False

def has_japanese(text):
    """Check if text contains Japanese characters"""
    return bool(re.search(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]', text))

def is_meaningful_dialogue(text):
    """Check if text is meaningful dialogue/description (not just markers)"""
    # Must have at least some alphabetic characters
    if not re.search(r'[a-zA-Z]', text):
        return False

    # Extract actual words (not in action markers)
    # Remove action markers first
    text_without_markers = re.sub(r'::[^:]+::', '', text)

    # Must have some actual words left
    words = re.findall(r'\b[a-zA-Z]+\b', text_without_markers)
    return len(words) >= 2  # At least 2 words of dialogue

def main():
    print("Loading files...")

    # Load glossary
    do_not_translate = load_glossary()
    print(f"Loaded {len(do_not_translate)} do_not_translate terms")

    # Read all three files
    en_path = 'translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt'
    es_path = 'translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt'
    ja_path = 'translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt'

    with open(en_path, 'r', encoding='utf-8') as f:
        en_lines = f.readlines()

    with open(es_path, 'r', encoding='utf-8') as f:
        es_lines = f.readlines()

    with open(ja_path, 'r', encoding='utf-8') as f:
        ja_lines = f.readlines()

    print("Analyzing entries...")

    untranslated_entries = []

    for line_num, (en, es, ja) in enumerate(zip(en_lines, es_lines, ja_lines), 1):
        if 'string data' not in en:
            continue

        en_text = extract_string_data(en)
        es_text = extract_string_data(es)
        ja_text = extract_string_data(ja)

        if en_text is None or es_text is None or ja_text is None:
            continue

        # Skip if should not translate (technical terms, etc.)
        if should_not_translate(en_text, do_not_translate):
            continue

        # Skip if Spanish didn't translate (meaning it's technical/proper noun that shouldn't be translated)
        if es_text == "" or es_text == en_text:
            continue

        # Skip if not meaningful dialogue
        if not is_meaningful_dialogue(en_text):
            continue

        # Check if Japanese == English (untranslated)
        if en_text == ja_text and not has_japanese(ja_text):
            untranslated_entries.append({
                'line': line_num,
                'text': en_text[:100],  # First 100 chars for preview
                'full_text': en_text
            })

    # Output results
    print(f"\n{'='*80}")
    print(f"UNTRANSLATED ENTRIES FOUND: {len(untranslated_entries)}")
    print(f"{'='*80}\n")

    if len(untranslated_entries) == 0:
        print("✅ No untranslated entries found!")
        return

    # Show summary by range
    print("Summary by line range:")
    ranges = [(1, 50000), (50001, 100000), (100001, 150000), (150001, 200000), (200001, 300000), (300001, 530425)]
    for start, end in ranges:
        count = len([e for e in untranslated_entries if start <= e['line'] <= end])
        if count > 0:
            print(f"  Lines {start:6d}-{end:6d}: {count:4d} entries")

    # Show first 50 entries
    print(f"\nFirst 50 untranslated entries:")
    print(f"{'-'*80}")
    for i, entry in enumerate(untranslated_entries[:50], 1):
        print(f"{i:3d}. Line {entry['line']:6d}: {entry['text']}")

    # Save full list to file
    output_file = 'translation/untranslated_entries.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(untranslated_entries, f, ensure_ascii=False, indent=2)

    print(f"\n{'='*80}")
    print(f"Full list saved to: {output_file}")
    print(f"{'='*80}")

    # Also save just line numbers for easy processing
    line_numbers_file = 'translation/untranslated_lines.txt'
    with open(line_numbers_file, 'w', encoding='utf-8') as f:
        for entry in untranslated_entries:
            f.write(f"{entry['line']}\n")

    print(f"Line numbers saved to: {line_numbers_file}")
    print()

if __name__ == '__main__':
    main()
