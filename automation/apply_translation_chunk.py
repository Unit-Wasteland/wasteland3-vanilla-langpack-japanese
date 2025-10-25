#!/usr/bin/env python3
"""
Apply translations from backup_broken file to target file for a specific line range.
Converts Japanese brackets (「」) to Unity format ("") while preserving structure.
"""

import sys
import re

def convert_line(line):
    """Convert Japanese text line to proper Unity format."""
    # Skip non-data lines
    if 'string data = ' not in line:
        return line

    # Extract indentation and content
    match = re.match(r'^(\s+\d+\s+string data = )(.*)', line)
    if not match:
        return line

    prefix, content = match.groups()

    # Handle empty strings
    if content.strip() == '""':
        return line

    # Handle Script Node (no translation needed)
    if 'Script Node' in content:
        return line

    # Handle action markup (::action::) - keep as-is
    if content.strip().startswith('::') and content.strip().endswith('::'):
        return line

    # Extract action markup prefix if exists
    action_prefix = ''
    action_match = re.match(r'^(::[\w]+:: )', content)
    if action_match:
        action_prefix = action_match.group(1)
        content = content[len(action_prefix):]

    # Convert Japanese brackets to Unity format
    # From: 「text」 or "「text」"
    # To: ""text""

    # Remove outer quotes if present
    content = content.strip()
    if content.startswith('"') and content.endswith('"'):
        content = content[1:-1]

    # Remove Japanese brackets
    content = content.replace('「', '').replace('」', '')
    content = content.replace('『', '').replace('』', '')

    # Rebuild with Unity format
    return f'{prefix}{action_prefix}""{content}""\n'

def main():
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <backup_file> <target_file> <start_line> <end_line>")
        sys.exit(1)

    backup_file = sys.argv[1]
    target_file = sys.argv[2]
    start_line = int(sys.argv[3])
    end_line = int(sys.argv[4])

    # Read backup file (Japanese with broken format)
    with open(backup_file, 'r', encoding='utf-8') as f:
        backup_lines = f.readlines()

    # Read target file (English with correct format)
    with open(target_file, 'r', encoding='utf-8') as f:
        target_lines = f.readlines()

    # Process specified range
    for i in range(start_line - 1, min(end_line, len(backup_lines))):
        backup_line = backup_lines[i]

        # Only process string data lines that have content
        if 'string data = ' in backup_line and '""' not in backup_line and 'Script Node' not in backup_line:
            converted = convert_line(backup_line)
            target_lines[i] = converted
        else:
            # Keep structure lines as-is from target (correct format)
            pass

    # Write updated target file
    with open(target_file, 'w', encoding='utf-8') as f:
        f.writelines(target_lines)

    print(f"Applied translations from lines {start_line} to {end_line}")

if __name__ == '__main__':
    main()
