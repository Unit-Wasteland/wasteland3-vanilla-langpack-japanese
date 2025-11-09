#!/usr/bin/env python3
"""
Auto-Fix Untranslated Entries Script

Automatically translates entries that were missed during translation sessions.
Uses the same unified translation decision logic as the main workflow.

Usage:
    python3 auto-fix-untranslated.py TARGET_FILE SOURCE_FILE REFERENCE_FILE \\
        [--start-line START] [--end-line END] [--glossary GLOSSARY_FILE]

Returns:
    0 - All untranslated entries fixed successfully
    1 - No untranslated entries found (nothing to fix)
    2 - Error occurred during fixing
"""

import sys
import re
import json
import argparse
from pathlib import Path

def load_glossary(glossary_path):
    """Load translation glossary"""
    if not glossary_path or not Path(glossary_path).exists():
        return {}

    with open(glossary_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    glossary = {}

    # Proper nouns (characters, locations, factions, items)
    for category in ['characters', 'locations', 'factions', 'items']:
        if category in data:
            for entry in data[category]:
                if 'english' in entry and 'japanese' in entry:
                    glossary[entry['english']] = entry['japanese']

    return glossary

def load_do_not_translate_list(glossary_path):
    """Load do-not-translate list from glossary"""
    if not glossary_path or not Path(glossary_path).exists():
        return set()

    with open(glossary_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    do_not_translate = set()
    if 'do_not_translate' in data:
        for entry in data['do_not_translate']:
            if isinstance(entry, dict) and 'term' in entry:
                do_not_translate.add(entry['term'])
            elif isinstance(entry, str):
                do_not_translate.add(entry)

    return do_not_translate

def load_string_data_lines(file_path):
    """Load all string data lines from a file"""
    lines = {}
    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            if 'string data = ' in line:
                lines[line_num] = line.rstrip('\n')
    return lines

def extract_text_from_string_data(line):
    """Extract text content from 'string data = ...' line"""
    match = re.search(r'string data = (.*)$', line)
    if match:
        return match.group(1)
    return ""

def should_not_translate(text, do_not_translate_list):
    """Check if text matches do-not-translate patterns"""
    # Empty string
    if text == '""':
        return True

    # Extract inner content
    inner = text.strip('"')

    # Check exact matches
    for term in do_not_translate_list:
        if term in inner:
            return True

    # Check patterns
    patterns = [
        r'^Script Node',
        r'^\[Global:',
        r'^\[Dropset:',
        r'^\[Reward:',
        r'^\[Switch to',
    ]

    for pattern in patterns:
        if re.match(pattern, inner):
            return True

    return False

def is_japanese(text):
    """Check if text contains Japanese characters"""
    return bool(re.search(r'[ぁ-ゖァ-ヾ一-龯]', text))

def translate_with_glossary(text, glossary):
    """Apply glossary translations to text"""
    for english, japanese in glossary.items():
        # Use word boundaries to avoid partial matches
        pattern = r'\b' + re.escape(english) + r'\b'
        text = re.sub(pattern, japanese, text, flags=re.IGNORECASE)
    return text

def simple_translate(text, glossary):
    """
    Simple translation function for auto-fix.
    This is a basic implementation - for complex dialogue, manual review is recommended.
    """
    # Preserve action markers
    action_markers = re.findall(r'::[^:]+::', text)

    # Replace action markers with placeholders
    temp_text = text
    for i, marker in enumerate(action_markers):
        temp_text = temp_text.replace(marker, f'__ACTION_{i}__', 1)

    # Apply glossary translations
    translated = translate_with_glossary(temp_text, glossary)

    # Note: This is where you would add more sophisticated translation
    # For now, we only apply glossary terms. Complex sentences need manual translation.

    # Restore action markers
    for i, marker in enumerate(action_markers):
        translated = translated.replace(f'__ACTION_{i}__', marker, 1)

    return translated

def fix_untranslated_entries(target_file, source_file, reference_file,
                             start_line=1, end_line=None, glossary_file=None):
    """
    Find and fix untranslated entries in target file.

    Returns:
        (fixed_count, error_count) tuple
    """
    print(f"Loading files...")
    print(f"  Target: {target_file}")
    print(f"  Source: {source_file}")
    print(f"  Reference: {reference_file}")

    # Load glossary and do-not-translate list
    glossary = load_glossary(glossary_file) if glossary_file else {}
    do_not_translate = load_do_not_translate_list(glossary_file) if glossary_file else set()

    print(f"  Glossary: {len(glossary)} terms")
    print(f"  Do-not-translate: {len(do_not_translate)} patterns")

    # Load all files
    target_lines = load_string_data_lines(target_file)
    source_lines = load_string_data_lines(source_file)
    reference_lines = load_string_data_lines(reference_file)

    # Read full target file for modification
    with open(target_file, 'r', encoding='utf-8') as f:
        target_full = f.readlines()

    fixes_needed = []

    # Scan for untranslated entries
    print(f"\nScanning lines {start_line} to {end_line or 'EOF'}...")

    for line_num in sorted(target_lines.keys()):
        if line_num < start_line:
            continue
        if end_line and line_num > end_line:
            break

        target_text = extract_text_from_string_data(target_lines[line_num])
        source_text = extract_text_from_string_data(source_lines.get(line_num, ""))
        reference_text = extract_text_from_string_data(reference_lines.get(line_num, ""))

        # Skip if already translated to Japanese
        if is_japanese(target_text):
            continue

        # Skip if empty
        if target_text == '""':
            continue

        # Skip if in do-not-translate list
        if should_not_translate(target_text, do_not_translate):
            continue

        # Check if Spanish is translated (reference for translatability)
        reference_inner = reference_text.strip('"')
        source_inner = source_text.strip('"')

        # Unified translation decision logic:
        # If Spanish is translated (non-empty and different from English),
        # then Japanese should also be translated
        if reference_text != '""' and reference_inner != source_inner:
            # This should be translated
            fixes_needed.append({
                'line_num': line_num,
                'target_text': target_text,
                'source_text': source_text,
                'reference_text': reference_text
            })

    if not fixes_needed:
        print("\n✓ No untranslated entries found")
        return 0, 0

    print(f"\n⚠ Found {len(fixes_needed)} untranslated entries")
    print("\nAttempting auto-fix...")

    fixed_count = 0
    error_count = 0

    for fix in fixes_needed:
        line_num = fix['line_num']
        source_text = fix['source_text']

        print(f"\n  Line {line_num}:")
        print(f"    EN: {source_text[:80]}...")

        # Extract inner content
        inner_text = source_text.strip('"')

        # Apply glossary-based translation
        translated = simple_translate(inner_text, glossary)

        # Check if translation occurred
        if translated != inner_text and is_japanese(translated):
            # Wrap in same quote format as source
            if source_text.startswith('""') and source_text.endswith('""'):
                translated_text = f'"{translated}"'
            else:
                translated_text = f'"{translated}"'

            # Update the line in target_full
            old_line = target_full[line_num - 1]
            new_line = re.sub(r'string data = .*$',
                            f'string data = {translated_text}',
                            old_line)

            target_full[line_num - 1] = new_line
            fixed_count += 1

            print(f"    JA: {translated_text[:80]}...")
            print(f"    ✓ Fixed using glossary")
        else:
            # Could not auto-translate (no glossary match)
            error_count += 1
            print(f"    ✗ Cannot auto-fix (no glossary match)")
            print(f"    → Manual translation required")

    if fixed_count > 0:
        # Write updated file
        print(f"\nWriting {fixed_count} fixes to {target_file}...")
        with open(target_file, 'w', encoding='utf-8') as f:
            f.writelines(target_full)
        print("✓ File updated")

    print(f"\n{'='*80}")
    print(f"Auto-fix Summary:")
    print(f"  Fixed: {fixed_count}")
    print(f"  Needs manual fix: {error_count}")
    print(f"{'='*80}")

    return fixed_count, error_count

def main():
    parser = argparse.ArgumentParser(
        description='Auto-fix untranslated entries in translation file'
    )
    parser.add_argument('target_file', help='Target translation file (ja_JP)')
    parser.add_argument('source_file', help='Source file (en_US)')
    parser.add_argument('reference_file', help='Reference file (es_ES)')
    parser.add_argument('--start-line', type=int, default=1,
                       help='Start line for scanning (default: 1)')
    parser.add_argument('--end-line', type=int, default=None,
                       help='End line for scanning (default: EOF)')
    parser.add_argument('--glossary', default=None,
                       help='Glossary JSON file')

    args = parser.parse_args()

    try:
        fixed, errors = fix_untranslated_entries(
            args.target_file,
            args.source_file,
            args.reference_file,
            start_line=args.start_line,
            end_line=args.end_line,
            glossary_file=args.glossary
        )

        if fixed == 0 and errors == 0:
            # Nothing to fix
            return 1
        elif errors > 0:
            # Some entries need manual fix
            return 2
        else:
            # All fixed successfully
            return 0

    except Exception as e:
        print(f"\n❌ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 2

if __name__ == '__main__':
    sys.exit(main())
