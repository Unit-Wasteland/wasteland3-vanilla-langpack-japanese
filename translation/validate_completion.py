#!/usr/bin/env python3
"""
Completion Validation Script for Wasteland 3 Japanese Translation Project

This script validates whether a translation file is truly 100% complete by:
1. Scanning the entire file for untranslated English entries
2. Calculating accurate completion rates
3. Providing Pass/Fail determination based on strict criteria

Usage:
    python3 validate_completion.py <target_file> [--verbose] [--output <file>]

Exit codes:
    0 = Complete (100%, no untranslated entries)
    1 = Incomplete (untranslated entries found)
    2 = Error (file not found, parsing error, etc.)
"""

import sys
import re
import argparse
from pathlib import Path
from typing import Dict, List, Tuple

class CompletionValidator:
    def __init__(self, target_file: str, verbose: bool = False):
        self.target_file = Path(target_file)
        self.verbose = verbose
        self.results = {
            'total_lines': 0,
            'total_string_data_lines': 0,
            'empty_entries': 0,
            'non_empty_entries': 0,
            'japanese_only': 0,
            'english_only': 0,
            'mixed_jp_en': 0,
            'other_entries': 0,
            'untranslated_lines': [],
            'mixed_lines': []
        }

    def validate(self) -> Dict:
        """Run validation and return results."""
        if not self.target_file.exists():
            print(f"ERROR: File not found: {self.target_file}")
            sys.exit(2)

        self._scan_file()
        self._calculate_metrics()
        return self.results

    def _scan_file(self):
        """Scan the entire file and categorize each entry."""
        print(f"Scanning file: {self.target_file.name}")

        with open(self.target_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        self.results['total_lines'] = len(lines)

        for line_num, line in enumerate(lines, 1):
            # Check if this is a string data line
            if 'string data = ""' not in line or not line.strip().endswith('""'):
                continue

            self.results['total_string_data_lines'] += 1

            # Extract content between the outer double quotes
            try:
                content = line.split('string data = ""')[1].rsplit('""', 1)[0]
            except (IndexError, ValueError):
                if self.verbose:
                    print(f"WARNING: Failed to parse line {line_num}")
                continue

            # Check if empty or whitespace only
            if not content or content.isspace():
                self.results['empty_entries'] += 1
                continue

            self.results['non_empty_entries'] += 1

            # Categorize the entry
            category = self._categorize_entry(content, line_num)

            if category == 'english_only':
                self.results['english_only'] += 1
                self.results['untranslated_lines'].append({
                    'line': line_num,
                    'content': content[:100] + '...' if len(content) > 100 else content
                })
            elif category == 'japanese_only':
                self.results['japanese_only'] += 1
            elif category == 'mixed':
                self.results['mixed_jp_en'] += 1
                self.results['mixed_lines'].append({
                    'line': line_num,
                    'content': content[:100] + '...' if len(content) > 100 else content
                })
            else:
                self.results['other_entries'] += 1

    def _categorize_entry(self, content: str, line_num: int) -> str:
        """Categorize an entry as english_only, japanese_only, mixed, or other."""
        # Check for English (5+ consecutive ASCII letters)
        has_english = bool(re.search(r'[A-Za-z]{5,}', content))

        # Check for Japanese characters
        has_japanese = any(
            '\u3040' <= c <= '\u309F' or  # Hiragana
            '\u30A0' <= c <= '\u30FF' or  # Katakana
            '\u4E00' <= c <= '\u9FFF'     # Kanji
            for c in content
        )

        # Special cases: Technical terms that should not be translated
        # These are English but should not be counted as "untranslated"
        technical_patterns = [
            r'^Script Node \d+$',  # Script Node markers
            r'^\[Global:',         # Global variables
            r'^\[Switch to',       # Radio frequencies
            r'^DEBUG -',           # Debug messages
        ]

        for pattern in technical_patterns:
            if re.match(pattern, content.strip()):
                return 'other'

        if has_japanese and has_english:
            return 'mixed'
        elif has_japanese:
            return 'japanese_only'
        elif has_english:
            return 'english_only'
        else:
            return 'other'

    def _calculate_metrics(self):
        """Calculate completion metrics."""
        non_empty = self.results['non_empty_entries']

        if non_empty == 0:
            self.results['completion_rate'] = 0.0
            self.results['untranslated_rate'] = 0.0
            return

        japanese = self.results['japanese_only']
        english = self.results['english_only']

        self.results['completion_rate'] = (japanese / non_empty) * 100
        self.results['untranslated_rate'] = (english / non_empty) * 100

    def print_report(self, output_file: str = None):
        """Print validation report."""
        r = self.results

        # Prepare report text
        report_lines = []
        report_lines.append("=" * 80)
        report_lines.append("COMPLETION VALIDATION REPORT")
        report_lines.append("=" * 80)
        report_lines.append("")
        report_lines.append(f"File: {self.target_file.name}")
        report_lines.append(f"Total lines: {r['total_lines']:,}")
        report_lines.append(f"String data lines: {r['total_string_data_lines']:,}")
        report_lines.append("")
        report_lines.append("-" * 80)
        report_lines.append("ENTRY BREAKDOWN")
        report_lines.append("-" * 80)
        report_lines.append(f"Empty entries: {r['empty_entries']:,} (翻訳不要)")
        report_lines.append(f"Non-empty entries: {r['non_empty_entries']:,} (翻訳対象)")
        report_lines.append("")
        report_lines.append("Translation status (non-empty entries only):")
        report_lines.append(f"  ✅ Japanese only: {r['japanese_only']:,} ({r['completion_rate']:.1f}%)")
        report_lines.append(f"  ❌ English only: {r['english_only']:,} ({r['untranslated_rate']:.1f}%)")
        report_lines.append(f"  ⚠️  Mixed (JP+EN): {r['mixed_jp_en']:,} ({r['mixed_jp_en']/r['non_empty_entries']*100:.1f}%)")
        report_lines.append(f"  ℹ️  Other (symbols/technical): {r['other_entries']:,} ({r['other_entries']/r['non_empty_entries']*100:.1f}%)")
        report_lines.append("")
        report_lines.append("-" * 80)
        report_lines.append("COMPLETION STATUS")
        report_lines.append("-" * 80)

        is_complete = r['english_only'] == 0 and r['mixed_jp_en'] == 0

        if is_complete:
            report_lines.append("✅ PASS: File is 100% complete!")
            report_lines.append(f"   All {r['non_empty_entries']:,} translatable entries are in Japanese.")
            exit_code = 0
        else:
            report_lines.append("❌ FAIL: File is NOT complete!")
            report_lines.append(f"   Untranslated entries: {r['english_only']:,}")
            report_lines.append(f"   Partially translated: {r['mixed_jp_en']:,}")
            report_lines.append(f"   Total issues: {r['english_only'] + r['mixed_jp_en']:,}")
            exit_code = 1

        report_lines.append("")

        # Show sample untranslated entries if present
        if r['untranslated_lines']:
            report_lines.append("-" * 80)
            report_lines.append("SAMPLE UNTRANSLATED ENTRIES (first 20)")
            report_lines.append("-" * 80)
            for entry in r['untranslated_lines'][:20]:
                report_lines.append(f"Line {entry['line']:6}: {entry['content']}")

            if len(r['untranslated_lines']) > 20:
                report_lines.append(f"... and {len(r['untranslated_lines']) - 20} more")
            report_lines.append("")

        # Show sample mixed entries if present
        if r['mixed_lines']:
            report_lines.append("-" * 80)
            report_lines.append("SAMPLE MIXED ENTRIES (first 10)")
            report_lines.append("-" * 80)
            for entry in r['mixed_lines'][:10]:
                report_lines.append(f"Line {entry['line']:6}: {entry['content']}")

            if len(r['mixed_lines']) > 10:
                report_lines.append(f"... and {len(r['mixed_lines']) - 10} more")
            report_lines.append("")

        report_lines.append("=" * 80)

        # Output report
        report_text = '\n'.join(report_lines)
        print(report_text)

        if output_file:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(report_text)
            print(f"\nReport saved to: {output_file}")

        return exit_code


def main():
    parser = argparse.ArgumentParser(
        description='Validate translation completion for Wasteland 3 Japanese translation files'
    )
    parser.add_argument('target_file', help='Path to the target translation file')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('-o', '--output', help='Save report to file')

    args = parser.parse_args()

    validator = CompletionValidator(args.target_file, verbose=args.verbose)
    validator.validate()
    exit_code = validator.print_report(output_file=args.output)

    sys.exit(exit_code)


if __name__ == '__main__':
    main()
