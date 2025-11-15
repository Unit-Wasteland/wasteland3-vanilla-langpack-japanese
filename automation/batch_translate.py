#!/usr/bin/env python3
"""
Batch translation script for remaining untranslated entries
Follows CLAUDE.md strict rules
"""
import re
import sys
import json
from pathlib import Path

# File paths
TARGET_FILE = 'translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt'
SOURCE_FILE = 'translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt'
SPANISH_FILE = 'translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt'
GLOSSARY_FILE = 'translation/nouns_glossary.json'
LINE_LIST_FILE = 'automation/.need_translation.txt'

JAPANESE_PATTERN = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]')

# Load glossary
glossary = {}
if Path(GLOSSARY_FILE).exists():
    with open(GLOSSARY_FILE, 'r', encoding='utf-8') as f:
        glossary_data = json.load(f)
        for section_name, section_data in glossary_data.items():
            if isinstance(section_data, dict) and section_name != 'do_not_translate':
                glossary.update(section_data)

print(f"Loaded {len(glossary)} glossary terms")

# Load line numbers to translate
with open(LINE_LIST_FILE, 'r') as f:
    line_nums = [int(line.strip()) for line in f if line.strip()]

print(f"Total entries to process: {len(line_nums)}")

# Load files
with open(TARGET_FILE, 'r', encoding='utf-8') as f:
    target_lines = f.readlines()
with open(SOURCE_FILE, 'r', encoding='utf-8') as f:
    source_lines = f.readlines()
with open(SPANISH_FILE, 'r', encoding='utf-8') as f:
    spanish_lines = f.readlines()

# Process each line
translated_count = 0
skipped_count = 0

for line_num in line_nums:
    target_line = target_lines[line_num - 1]
    source_line = source_lines[line_num - 1]
    spanish_line = spanish_lines[line_num - 1]

    # Extract content
    target_match = re.search(r'string data = ""(.*)""', target_line)
    source_match = re.search(r'string data = ""(.*)""', source_line)
    spanish_match = re.search(r'string data = ""(.*?)"\."', spanish_line)

    if not target_match or not source_match:
        continue

    target_content = target_match.group(1)
    source_content = source_match.group(1)
    spanish_content = spanish_match.group(1) if spanish_match else ""

    # Check if already has Japanese
    if JAPANESE_PATTERN.search(target_content):
        skipped_count += 1
        continue

    # Simple translations (examples - extend this based on patterns)
    translations = {
        'Y\'know...': 'なあ...',
        'Zzzzzzzzzzzzz...': 'zzzzzzzzz...',
        'Zzzzzzzzzz...': 'zzzzzzzzz...',
        'Adios、compadres。': 'アディオス、コンパドレス。',
        'Adios。': 'アディオス。',
        'November。': 'ノヴェンバー。',
        'Aaaaah.': 'ああああ。',
        'VLAM?!': 'VLAM?!',  # Keep product name
        'BAMF?': 'BAMF?',  # Keep acronym
    }

    if source_content in translations:
        new_content = translations[source_content]
        new_line = target_line.replace(f'""{target_content}""', f'""{new_content}""')
        target_lines[line_num - 1] = new_line
        translated_count += 1
        print(f"Line {line_num}: {source_content} → {new_content}")

print(f"\nTranslated: {translated_count}")
print(f"Skipped (already Japanese): {skipped_count}")
print(f"Remaining: {len(line_nums) - translated_count - skipped_count}")

# Save
with open(TARGET_FILE, 'w', encoding='utf-8') as f:
    f.writelines(target_lines)

print(f"\nSaved to: {TARGET_FILE}")
