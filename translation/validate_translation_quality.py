#!/usr/bin/env python3
"""
Translation Quality Validator

Detects two major types of translation quality issues:
1. Incorrectly translated ::action:: markers (translated to Japanese instead of kept in English)
2. Untranslated English entries that should be translated
"""

import re
import sys
import argparse
from pathlib import Path
from typing import List, Tuple, Dict

# Japanese character ranges (Hiragana, Katakana, Kanji)
JAPANESE_CHAR_PATTERN = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]')

# Action marker pattern
ACTION_MARKER_PATTERN = re.compile(r'::[^:]+::')

# Technical terms that should NOT be translated
DO_NOT_TRANSLATE = [
    r'Script Node',
    r'\[Switch to',
    r'\[Global:',
    r'\[Dropset:',
    r'\[Reward:',
    r'DEBUG',
    r'Test',
]

# English word patterns (common words that indicate English text)
ENGLISH_PATTERNS = [
    r'\b(the|and|to|of|a|in|that|it|with|for|as|was|is|on|are|be|have|this|from|at|by|not|or|an|but|can|if|will|what|all|would|there|their|we|when|which|about|get|who|been|they|do|said|her|she|him|his|one|has|two|how|out|them|our|up|more|so|only|its|some|into|than|my|now|over|your|just|like|very|other|could|time|these|first|may|any|new|see|after|should|between|own|such|being|both|many|much|through|back|much|before|well|where|here|even|those|most|made|year|also|because|way|work|years|still|three|while|day|against|then|during|always|under|must|people|every|each|another|same|take|again|think|need|without|good|does|since|around|went|want|great|man|going|too|came|though|state|right|place|never|off|found|given|put|together|point|united|part|different|house|used|last|keep|best|called|better|known|tell|give|number|something|between|keep|often|rather|really|long|give|early|actually|several|perhaps|however)\b',
]

class ValidationIssue:
    def __init__(self, line_num: int, issue_type: str, description: str, line_content: str):
        self.line_num = line_num
        self.issue_type = issue_type
        self.description = description
        self.line_content = line_content

    def __repr__(self):
        return f"Line {self.line_num}: [{self.issue_type}] {self.description}"

def contains_japanese(text: str) -> bool:
    """Check if text contains Japanese characters."""
    return bool(JAPANESE_CHAR_PATTERN.search(text))

def is_technical_term(text: str) -> bool:
    """Check if text is a technical term that should not be translated."""
    for pattern in DO_NOT_TRANSLATE:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    return False

def contains_common_english(text: str) -> bool:
    """Check if text contains common English words."""
    for pattern in ENGLISH_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    return False

def extract_action_markers(text: str) -> List[str]:
    """Extract all ::action:: markers from text."""
    return ACTION_MARKER_PATTERN.findall(text)

def validate_action_markers(line_num: int, line: str) -> List[ValidationIssue]:
    """Validate that action markers are in English, not translated to Japanese."""
    issues = []

    if 'string data' not in line:
        return issues

    # Extract action markers
    markers = extract_action_markers(line)

    for marker in markers:
        # Check if marker contains Japanese characters
        if contains_japanese(marker):
            issues.append(ValidationIssue(
                line_num=line_num,
                issue_type="ACTION_MARKER_TRANSLATED",
                description=f"Action marker translated to Japanese: {marker}",
                line_content=line.strip()
            ))

    return issues

def validate_untranslated_english(line_num: int, line: str, start_line: int = 666, end_line: int = 999999999) -> List[ValidationIssue]:
    """Validate that English text is translated (within the specified range)."""
    issues = []

    # Only check within the specified line range
    if line_num < start_line or line_num > end_line:
        return issues

    # Only check string data lines
    if 'string data' not in line:
        return issues

    # Extract the string content
    match = re.search(r'string data = ""(.*)""', line)
    if not match:
        return issues

    content = match.group(1)

    # Skip empty strings
    if not content.strip():
        return issues

    # Skip if it's a technical term
    if is_technical_term(content):
        return issues

    # Skip if it contains action markers only
    markers = extract_action_markers(content)
    content_without_markers = content
    for marker in markers:
        content_without_markers = content_without_markers.replace(marker, '')

    if not content_without_markers.strip():
        return issues

    # Check if content contains common English words
    if contains_common_english(content):
        # Check if it also contains Japanese (partially translated)
        if contains_japanese(content):
            # This is partially translated, which might be okay (mixed dialogue)
            pass
        else:
            # This is fully in English, should be translated
            issues.append(ValidationIssue(
                line_num=line_num,
                issue_type="UNTRANSLATED_ENGLISH",
                description=f"English text not translated",
                line_content=line.strip()
            ))

    return issues

def validate_file(filepath: Path, start_line: int = 666, end_line: int = 999999999, verbose: bool = False) -> Dict[str, List[ValidationIssue]]:
    """Validate a translation file for quality issues."""
    issues = {
        'action_markers': [],
        'untranslated': [],
    }

    with open(filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, start=1):
            # Check action markers
            marker_issues = validate_action_markers(line_num, line)
            issues['action_markers'].extend(marker_issues)

            # Check untranslated English
            english_issues = validate_untranslated_english(line_num, line, start_line, end_line)
            issues['untranslated'].extend(english_issues)

    return issues

def print_report(issues: Dict[str, List[ValidationIssue]], verbose: bool = False):
    """Print validation report."""
    total_issues = sum(len(issue_list) for issue_list in issues.values())

    print("\n" + "="*80)
    print("TRANSLATION QUALITY VALIDATION REPORT")
    print("="*80)

    print(f"\nTotal issues found: {total_issues}")

    # Action marker issues
    action_marker_issues = issues['action_markers']
    print(f"\n[1] Action markers translated to Japanese: {len(action_marker_issues)}")
    if action_marker_issues:
        print("\nSample issues (first 20):")
        for issue in action_marker_issues[:20]:
            print(f"  Line {issue.line_num}: {issue.description}")
            if verbose:
                print(f"    Content: {issue.line_content}")

        if len(action_marker_issues) > 20:
            print(f"\n  ... and {len(action_marker_issues) - 20} more")

    # Untranslated English issues
    untranslated_issues = issues['untranslated']
    print(f"\n[2] Untranslated English entries: {len(untranslated_issues)}")
    if untranslated_issues:
        print("\nSample issues (first 20):")
        for issue in untranslated_issues[:20]:
            print(f"  Line {issue.line_num}: {issue.description}")
            if verbose:
                print(f"    Content: {issue.line_content}")

        if len(untranslated_issues) > 20:
            print(f"\n  ... and {len(untranslated_issues) - 20} more")

    print("\n" + "="*80)

    return total_issues

def save_detailed_report(issues: Dict[str, List[ValidationIssue]], output_file: Path):
    """Save detailed report to file."""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("Translation Quality Issues - Detailed Report\n")
        f.write("="*80 + "\n\n")

        # Action marker issues
        f.write(f"[1] Action markers translated to Japanese: {len(issues['action_markers'])}\n")
        f.write("-"*80 + "\n")
        for issue in issues['action_markers']:
            f.write(f"Line {issue.line_num}: {issue.description}\n")
            f.write(f"  {issue.line_content}\n\n")

        # Untranslated English issues
        f.write(f"\n[2] Untranslated English entries: {len(issues['untranslated'])}\n")
        f.write("-"*80 + "\n")
        for issue in issues['untranslated']:
            f.write(f"Line {issue.line_num}: {issue.description}\n")
            f.write(f"  {issue.line_content}\n\n")

def main():
    parser = argparse.ArgumentParser(description='Validate translation quality')
    parser.add_argument('file', type=str, help='Translation file to validate')
    parser.add_argument('--start-line', type=int, default=666, help='Start line for validation (default: 666)')
    parser.add_argument('--end-line', type=int, default=999999999, help='End line for validation (default: end of file)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--output', '-o', type=str, help='Save detailed report to file')

    args = parser.parse_args()

    filepath = Path(args.file)

    if not filepath.exists():
        print(f"Error: File not found: {filepath}")
        sys.exit(1)

    print(f"Validating: {filepath}")
    print(f"Range: lines {args.start_line} to {args.end_line}")

    issues = validate_file(filepath, args.start_line, args.end_line, args.verbose)
    total_issues = print_report(issues, args.verbose)

    if args.output:
        output_path = Path(args.output)
        save_detailed_report(issues, output_path)
        print(f"\nDetailed report saved to: {output_path}")

    sys.exit(0 if total_issues == 0 else 1)

if __name__ == '__main__':
    main()
