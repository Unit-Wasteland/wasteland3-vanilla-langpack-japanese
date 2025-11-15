#!/usr/bin/env python3
"""
Untranslated Entry Detector and Reporter

Scans translation files for untranslated English entries and generates detailed reports.
Can be used standalone or as part of the automated fix workflow.

Usage:
    python3 automation/detect-untranslated.py --file base_game
    python3 automation/detect-untranslated.py --file dlc1
    python3 automation/detect-untranslated.py --file dlc2
    python3 automation/detect-untranslated.py --file all
"""

import sys
import json
import argparse
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'translation'))

from validate_translation_quality import validate_file, print_report

# File paths
BASE_DIR = Path(__file__).parent.parent
TRANSLATION_DIR = BASE_DIR / 'translation'

FILE_CONFIGS = {
    'base_game': {
        'name': 'Base Game',
        'target': TRANSLATION_DIR / 'target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt',
        'reference': TRANSLATION_DIR / 'source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-f95544f6ef35e8a6587dccfa911ba0f8-9130184510981781208.txt',
        'glossary': TRANSLATION_DIR / 'nouns_glossary.json',
        'start_line': 390,
        'end_line': 530425,
    },
    'dlc1': {
        'name': 'DLC1 (Battle of Steeltown)',
        'target': TRANSLATION_DIR / 'target/v1.6.9.420.309496/ja_JP/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt',
        'reference': TRANSLATION_DIR / 'source/v1.6.9.420.309496/es_ES/DLC1/StringTableData_Spanish-CAB-c13efb82e7be9ceb56e2c80695d8eea2-2953265667691765933.txt',
        'glossary': TRANSLATION_DIR / 'nouns_glossary.json',
        'start_line': 390,
        'end_line': 120559,
    },
    'dlc2': {
        'name': 'DLC2 (Cult of the Holy Detonation)',
        'target': TRANSLATION_DIR / 'target/v1.6.9.420.309496/ja_JP/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt',
        'reference': TRANSLATION_DIR / 'source/v1.6.9.420.309496/es_ES/DLC2/StringTableData_Spanish-CAB-60eadccba37b16fa0e2ce3fd5e7bb77b--5098388710011535064.txt',
        'glossary': TRANSLATION_DIR / 'nouns_glossary.json',
        'start_line': 390,
        'end_line': 77353,
    },
}

def detect_untranslated_entries(file_key: str, verbose: bool = False, save_report: bool = True):
    """Detect untranslated entries in the specified file."""

    if file_key not in FILE_CONFIGS:
        print(f"Error: Unknown file key '{file_key}'")
        print(f"Available keys: {', '.join(FILE_CONFIGS.keys())}")
        return None

    config = FILE_CONFIGS[file_key]

    print(f"{'='*80}")
    print(f"Detecting Untranslated Entries: {config['name']}")
    print(f"{'='*80}")
    print(f"Target file: {config['target']}")
    print(f"Reference file: {config['reference']}")
    print(f"Line range: {config['start_line']} - {config['end_line']}")
    print()

    # Check if files exist
    if not config['target'].exists():
        print(f"Error: Target file not found: {config['target']}")
        return None

    if not config['reference'].exists():
        print(f"Warning: Reference file not found: {config['reference']}")
        print("Proceeding without Spanish reference...")
        config['reference'] = None

    # Run validation
    issues = validate_file(
        filepath=config['target'],
        reference_filepath=config['reference'],
        glossary_path=config['glossary'],
        start_line=config['start_line'],
        end_line=config['end_line'],
        verbose=verbose
    )

    # Print report
    total_issues = print_report(issues, verbose=verbose)

    # Save detailed report if requested
    if save_report and total_issues > 0:
        report_file = BASE_DIR / 'automation' / f'.untranslated_{file_key}_report.txt'

        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(f"Untranslated Entries Report - {config['name']}\n")
            f.write("="*80 + "\n\n")

            # Untranslated entries
            untranslated = issues['untranslated']
            f.write(f"Total untranslated entries: {len(untranslated)}\n")
            f.write("-"*80 + "\n\n")

            for issue in untranslated:
                f.write(f"Line {issue.line_num}:\n")
                f.write(f"  {issue.line_content}\n\n")

        print(f"\nDetailed report saved to: {report_file}")

        # Also save line numbers only
        lines_file = BASE_DIR / 'automation' / f'.untranslated_{file_key}_lines.txt'
        with open(lines_file, 'w', encoding='utf-8') as f:
            for issue in issues['untranslated']:
                f.write(f"{issue.line_num}\n")

        print(f"Line numbers saved to: {lines_file}")

    return issues

def main():
    parser = argparse.ArgumentParser(description='Detect untranslated entries in translation files')
    parser.add_argument('--file', '-f',
                       choices=['base_game', 'dlc1', 'dlc2', 'all'],
                       default='base_game',
                       help='Which file(s) to check (default: base_game)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose output (show line content)')
    parser.add_argument('--no-report', action='store_true',
                       help='Do not save detailed report files')

    args = parser.parse_args()

    if args.file == 'all':
        # Check all files
        total_untranslated = 0

        for file_key in ['base_game', 'dlc1', 'dlc2']:
            issues = detect_untranslated_entries(
                file_key=file_key,
                verbose=args.verbose,
                save_report=not args.no_report
            )

            if issues:
                total_untranslated += len(issues['untranslated'])

            print("\n")

        print(f"{'='*80}")
        print(f"SUMMARY: Total untranslated entries across all files: {total_untranslated}")
        print(f"{'='*80}")

        sys.exit(0 if total_untranslated == 0 else 1)
    else:
        # Check single file
        issues = detect_untranslated_entries(
            file_key=args.file,
            verbose=args.verbose,
            save_report=not args.no_report
        )

        if issues is None:
            sys.exit(1)

        untranslated_count = len(issues['untranslated'])
        sys.exit(0 if untranslated_count == 0 else 1)

if __name__ == '__main__':
    main()
