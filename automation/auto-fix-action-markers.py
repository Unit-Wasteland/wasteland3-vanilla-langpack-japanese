#!/usr/bin/env python3
"""
Auto-Fix Action Markers

Automatically fixes action markers that were incorrectly translated to Japanese.
Uses English source file to restore correct action markers.

Usage:
    python3 auto-fix-action-markers.py TARGET_FILE SOURCE_FILE [--dry-run]

Returns:
    0 - Fixes applied successfully
    1 - No fixes needed or errors occurred
"""

import re
import sys
import argparse
from pathlib import Path
from typing import List, Tuple, Dict

# Japanese character pattern
JAPANESE_PATTERN = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]')

# Action marker pattern
ACTION_MARKER_PATTERN = re.compile(r'::[^:]+::')

def contains_japanese(text: str) -> bool:
    """Check if text contains Japanese characters."""
    return bool(JAPANESE_PATTERN.search(text))

def extract_action_markers(line: str) -> List[Tuple[str, int, int]]:
    """Extract all action markers from a line with their positions.

    Returns list of (marker_text, start_pos, end_pos)
    """
    markers = []
    for match in ACTION_MARKER_PATTERN.finditer(line):
        markers.append((match.group(), match.start(), match.end()))
    return markers

def find_japanese_markers(line: str) -> List[Tuple[str, int, int]]:
    """Find action markers containing Japanese characters.

    Returns list of (marker_text, start_pos, end_pos)
    """
    markers = extract_action_markers(line)
    japanese_markers = []

    for marker_text, start, end in markers:
        if contains_japanese(marker_text):
            japanese_markers.append((marker_text, start, end))

    return japanese_markers

def fix_line(ja_line: str, en_line: str) -> Tuple[str, int]:
    """Fix action markers in Japanese line using English source.

    Returns: (fixed_line, fix_count)
    """
    # Extract markers from both lines
    ja_markers = extract_action_markers(ja_line)
    en_markers = extract_action_markers(en_line)

    # If no markers in English, can't fix
    if not en_markers:
        return ja_line, 0

    # If marker count doesn't match, use simple replacement
    if len(ja_markers) != len(en_markers):
        print(f"    ⚠ Marker count mismatch (JA: {len(ja_markers)}, EN: {len(en_markers)})", file=sys.stderr)
        # Replace all markers sequentially
        fixed = ja_line
        for en_marker, _, _ in en_markers:
            # Replace first occurrence of any action marker with English version
            fixed = ACTION_MARKER_PATTERN.sub(en_marker, fixed, count=1)
        return fixed, len(en_markers)

    # Replace markers in reverse order to preserve positions
    fixed = ja_line
    fix_count = 0

    for (ja_marker, ja_start, ja_end), (en_marker, _, _) in zip(reversed(ja_markers), reversed(en_markers)):
        if ja_marker != en_marker:
            # Replace this specific marker
            fixed = fixed[:ja_start] + en_marker + fixed[ja_end:]
            fix_count += 1

    return fixed, fix_count

def auto_fix_file(target_path: Path, source_path: Path, dry_run: bool = False) -> Tuple[int, List[str]]:
    """Auto-fix action markers in target file.

    Returns: (total_fixes, list_of_fixed_lines_info)
    """
    print(f"Reading target file: {target_path}")
    with open(target_path, 'r', encoding='utf-8') as f:
        ja_lines = f.readlines()

    print(f"Reading source file: {source_path}")
    with open(source_path, 'r', encoding='utf-8') as f:
        en_lines = f.readlines()

    if len(ja_lines) != len(en_lines):
        print(f"ERROR: Line count mismatch (JA: {len(ja_lines)}, EN: {len(en_lines)})", file=sys.stderr)
        return 0, []

    print(f"Scanning {len(ja_lines)} lines for Japanese action markers...")

    total_fixes = 0
    fixed_lines_info = []
    fixed_lines = []

    for line_num, (ja_line, en_line) in enumerate(zip(ja_lines, en_lines), start=1):
        # Check if this line has action markers with Japanese
        japanese_markers = find_japanese_markers(ja_line)

        if not japanese_markers:
            fixed_lines.append(ja_line)
            continue

        # This line needs fixing
        print(f"  Line {line_num}: Found {len(japanese_markers)} Japanese action marker(s)")
        for marker, _, _ in japanese_markers:
            print(f"    → {marker}")

        # Fix the line
        fixed_line, fix_count = fix_line(ja_line, en_line)

        if fix_count > 0:
            en_markers = [m for m, _, _ in extract_action_markers(en_line)]
            print(f"    ✓ Fixed with: {', '.join(en_markers)}")
            total_fixes += fix_count
            fixed_lines_info.append(f"Line {line_num}: {fix_count} marker(s) fixed")
            fixed_lines.append(fixed_line)
        else:
            print(f"    ⚠ Could not fix")
            fixed_lines.append(ja_line)

    if total_fixes > 0:
        print(f"\n✓ Total fixes: {total_fixes} action marker(s)")

        if not dry_run:
            # Create backup
            backup_path = target_path.with_suffix(target_path.suffix + '.autofix.bak')
            print(f"Creating backup: {backup_path}")
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.writelines(ja_lines)

            # Write fixed content
            print(f"Writing fixed content to: {target_path}")
            with open(target_path, 'w', encoding='utf-8') as f:
                f.writelines(fixed_lines)

            print("✅ Auto-fix completed successfully")
        else:
            print("🔍 Dry-run mode: No changes written")
    else:
        print("\n✓ No Japanese action markers found")

    return total_fixes, fixed_lines_info

def main():
    parser = argparse.ArgumentParser(description='Auto-fix action markers translated to Japanese')
    parser.add_argument('target_file', type=str, help='Target Japanese translation file')
    parser.add_argument('source_file', type=str, help='Source English file')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be fixed without applying changes')

    args = parser.parse_args()

    target_path = Path(args.target_file)
    source_path = Path(args.source_file)

    if not target_path.exists():
        print(f"ERROR: Target file not found: {target_path}", file=sys.stderr)
        sys.exit(1)

    if not source_path.exists():
        print(f"ERROR: Source file not found: {source_path}", file=sys.stderr)
        sys.exit(1)

    print("=" * 80)
    print("Auto-Fix Action Markers")
    print("=" * 80)

    try:
        total_fixes, fixed_info = auto_fix_file(target_path, source_path, args.dry_run)

        if total_fixes > 0:
            print("\nFixed lines:")
            for info in fixed_info:
                print(f"  - {info}")
            sys.exit(0)
        else:
            sys.exit(1)  # No fixes needed

    except Exception as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
