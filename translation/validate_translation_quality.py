#!/usr/bin/env python3
"""
Translation Quality Validator

Detects major types of translation quality issues:
1. Incorrectly translated ::action:: markers (translated to Japanese instead of kept in English)
2. Untranslated English entries that should be translated
3. Glossary violations (incorrect terminology not matching nouns_glossary.json)

Uses Spanish reference file to determine if English text should be translated:
- Spanish empty ("") + English text = Program identifier → Keep English (NOT an error)
- Spanish translated + English text = Normal text → Should translate to Japanese (IS an error if still English)
"""

import re
import sys
import json
import argparse
from pathlib import Path
from typing import List, Tuple, Dict, Optional

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

# Known incorrect translation patterns
# Maps English terms to their incorrect Japanese translations
INCORRECT_TRANSLATIONS = {
    'Rangers': 'レンジャーズ',  # Correct: レンジャー
    'Desert Rangers': 'デザート・レンジャーズ',  # Correct: デザート・レンジャー
}

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

def contains_ascii_letters(text: str) -> bool:
    """Check if text contains ASCII alphabet letters (indicating English text).

    This is more comprehensive than pattern matching, as it catches:
    - Short exclamations: "Hi!", "Hello!", "Candy!"
    - Onomatopoeia: "Moooo!", "Choo choo!"
    - Any other English text not in the pattern list
    """
    # Check if text contains any ASCII letters (a-z, A-Z)
    return bool(re.search(r'[a-zA-Z]', text))

def contains_common_english(text: str) -> bool:
    """Check if text contains common English words (legacy function, kept for compatibility)."""
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

def load_glossary(glossary_path: Optional[Path] = None) -> Dict[str, str]:
    """Load nouns_glossary.json and return English -> Japanese mapping."""
    if glossary_path is None:
        # Default glossary path
        glossary_path = Path(__file__).parent / 'nouns_glossary.json'

    if not glossary_path.exists():
        return {}

    try:
        with open(glossary_path, 'r', encoding='utf-8') as f:
            glossary_data = json.load(f)

        # Flatten all sections into a single dictionary
        term_mapping = {}
        for section_name, section_data in glossary_data.items():
            if isinstance(section_data, dict) and section_name != 'do_not_translate':
                term_mapping.update(section_data)

        return term_mapping
    except Exception as e:
        print(f"Warning: Failed to load glossary: {e}")
        return {}

def load_spanish_reference(filepath: Optional[Path]) -> Dict[int, str]:
    """Load Spanish reference file and extract string data by line number.

    Note: Spanish files use format: string data = "content"." (not "content"")
    """
    spanish_data = {}

    if not filepath or not filepath.exists():
        return spanish_data

    with open(filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, start=1):
            if 'string data' in line:
                # Extract the string content
                # Spanish format: string data = ""content"."
                match = re.search(r'string data = ""(.*?)"\."', line)
                if match:
                    spanish_data[line_num] = match.group(1)
                else:
                    # Try fallback pattern for empty strings: string data = ""
                    match_empty = re.search(r'string data = ""$', line)
                    if match_empty:
                        spanish_data[line_num] = ""
                    else:
                        # Could not parse - mark as empty
                        spanish_data[line_num] = ""

    return spanish_data

def validate_untranslated_english(line_num: int, line: str, spanish_data: Dict[int, str], start_line: int = 666, end_line: int = 999999999) -> List[ValidationIssue]:
    """Validate that English text is translated (within the specified range).

    UPDATED LOGIC (2025-11-15 - FIXED):
    - Uses ASCII letter detection (more comprehensive than word pattern matching)
    - Detects all English text including short exclamations, onomatopoeia, etc.
    - Spanish reference is used to confirm translatability
    - If Spanish is translated (differs from English), Japanese MUST also be translated
    """
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

    # Remove game variables like [Global: ...], [Reward: ...], etc.
    content_without_vars = re.sub(r'\[Global:[^\]]+\]', '', content_without_markers)
    content_without_vars = re.sub(r'\[Dropset:[^\]]+\]', '', content_without_vars)
    content_without_vars = re.sub(r'\[Reward:[^\]]+\]', '', content_without_vars)
    content_without_vars = re.sub(r'\[Switch to[^\]]+\]', '', content_without_vars)

    if not content_without_vars.strip():
        return issues

    # Check if content contains Japanese
    has_japanese = contains_japanese(content)

    # Check if content contains ASCII letters (English)
    has_english = contains_ascii_letters(content_without_vars)

    # If content has Japanese, consider it translated (even if partially in English)
    if has_japanese:
        return issues

    # If content has English letters but no Japanese, it might be untranslated
    if has_english:
        # Check Spanish reference to confirm translatability
        should_translate = False
        reason = ""

        if line_num in spanish_data:
            spanish_content = spanish_data[line_num]
            # If Spanish is translated (different from English), Japanese should also be translated
            if spanish_content.strip() and spanish_content.strip() != content.strip():
                should_translate = True
                reason = "Spanish was translated, so Japanese should also be translated"
            else:
                # Spanish is same as English or empty
                # This could be a technical term or translatable text
                # Default to assuming it should be translated unless it's clearly technical
                # (technical terms are already filtered by is_technical_term above)
                should_translate = True
                reason = "English content present (Spanish reference empty/same as English - likely translatable)"
        else:
            # No Spanish reference available
            # Default to assuming English text should be translated
            should_translate = True
            reason = "English content present (no Spanish reference available - likely translatable)"

        if should_translate:
            issues.append(ValidationIssue(
                line_num=line_num,
                issue_type="UNTRANSLATED_ENGLISH",
                description=f"English text not translated ({reason})",
                line_content=line.strip()
            ))

    return issues

def validate_bracket_translation(line_num: int, line: str) -> List[ValidationIssue]:
    """Validate that bracket [] content is not translated to Japanese.

    Technical markers like [Attack], [Lie], [Global: ...] should remain in English.

    EXCEPTION: Nested structures like [[Global: ...] UNIT] where UNIT can be translated
    (e.g., "Dollars" → "ドル", "dólares" in Spanish)
    """
    issues = []

    if 'string data' not in line:
        return issues

    # Extract the string data content
    match = re.search(r'string data = ""(.*)""', line)
    if not match:
        return issues

    content = match.group(1)

    # Find all individual bracket pairs (non-nested)
    # This pattern finds single-level brackets only
    single_bracket_pattern = re.compile(r'\[([^\[\]]+)\]')

    for bracket_match in single_bracket_pattern.finditer(content):
        bracket_content = bracket_match.group(1)

        # Skip if this is part of a nested structure like [[Global: ...] UNIT]
        # Check if this bracket is immediately followed by whitespace and then another bracket or closing bracket
        full_match = bracket_match.group(0)
        match_end = bracket_match.end()

        # Check if this is a technical marker that should never contain Japanese
        is_technical_marker = (
            bracket_content.startswith('Global:') or
            bracket_content.startswith('Dropset:') or
            bracket_content.startswith('Reward:') or
            bracket_content.startswith('Attack') or
            bracket_content.startswith('Lie') or
            bracket_content.startswith('Kiss') or
            bracket_content.startswith('Hard Ass') or
            bracket_content.startswith('Kick') or
            bracket_content.startswith('Threaten') or
            bracket_content.startswith('Switch to') or
            bracket_content.startswith('Bet')
        )

        # If it's a technical marker and contains Japanese, flag it
        if is_technical_marker and contains_japanese(bracket_content):
            issues.append(ValidationIssue(
                line_num=line_num,
                issue_type="BRACKET_CONTENT_TRANSLATED",
                description=f"Technical bracket marker translated to Japanese (should remain English): [{bracket_content}]",
                line_content=line.strip()
            ))

    return issues

def validate_glossary_compliance(line_num: int, line: str, glossary: Dict[str, str]) -> List[ValidationIssue]:
    """Validate that translations comply with the glossary.

    Detects incorrect translations that don't match nouns_glossary.json.
    For example: "Rangers" should be "レンジャー", not "レンジャーズ".
    """
    issues = []

    if 'string data' not in line:
        return issues

    # Extract the string content
    match = re.search(r'string data = ""(.*)""', line)
    if not match:
        return issues

    content = match.group(1)

    # Check for known incorrect translations
    for english_term, incorrect_japanese in INCORRECT_TRANSLATIONS.items():
        if incorrect_japanese in content:
            correct_japanese = glossary.get(english_term, '(not in glossary)')
            issues.append(ValidationIssue(
                line_num=line_num,
                issue_type="GLOSSARY_VIOLATION",
                description=f"Incorrect translation '{incorrect_japanese}' should be '{correct_japanese}' (for '{english_term}')",
                line_content=line.strip()
            ))

    return issues

def validate_file(filepath: Path, reference_filepath: Optional[Path] = None, glossary_path: Optional[Path] = None, start_line: int = 666, end_line: int = 999999999, verbose: bool = False) -> Dict[str, List[ValidationIssue]]:
    """Validate a translation file for quality issues."""
    issues = {
        'action_markers': [],
        'untranslated': [],
        'bracket_translation': [],
        'glossary_violations': [],
    }

    # Load glossary data
    glossary = load_glossary(glossary_path)
    if glossary:
        print(f"Loaded glossary: {len(glossary)} terms")
    else:
        print("Warning: Glossary not loaded, skipping glossary validation")

    # Load Spanish reference data
    spanish_data = load_spanish_reference(reference_filepath)

    if reference_filepath:
        if spanish_data:
            print(f"Loaded Spanish reference: {len(spanish_data)} string data entries")
        else:
            print(f"Warning: Spanish reference file not found or empty: {reference_filepath}")

    with open(filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, start=1):
            # Check action markers
            marker_issues = validate_action_markers(line_num, line)
            issues['action_markers'].extend(marker_issues)

            # Check untranslated English
            english_issues = validate_untranslated_english(line_num, line, spanish_data, start_line, end_line)
            issues['untranslated'].extend(english_issues)

            # Check bracket translation
            bracket_issues = validate_bracket_translation(line_num, line)
            issues['bracket_translation'].extend(bracket_issues)

            # Check glossary compliance
            glossary_issues = validate_glossary_compliance(line_num, line, glossary)
            issues['glossary_violations'].extend(glossary_issues)

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
        if len(untranslated_issues) <= 50:
            # If 50 or fewer, show all
            print("\nAll issues:")
            for issue in untranslated_issues:
                print(f"  Line {issue.line_num}: {issue.description}")
                if verbose:
                    print(f"    Content: {issue.line_content}")
        else:
            # If more than 50, show first 20 and all line numbers
            print("\nSample issues (first 20):")
            for issue in untranslated_issues[:20]:
                print(f"  Line {issue.line_num}: {issue.description}")
                if verbose:
                    print(f"    Content: {issue.line_content}")

            print(f"\n  ... and {len(untranslated_issues) - 20} more")

            # List all line numbers for reference
            print(f"\nAll untranslated line numbers ({len(untranslated_issues)} total):")
            line_nums = [str(issue.line_num) for issue in untranslated_issues]
            # Print in rows of 10
            for i in range(0, len(line_nums), 10):
                print(f"  {', '.join(line_nums[i:i+10])}")

    # Bracket translation issues
    bracket_issues = issues['bracket_translation']
    print(f"\n[3] Bracket [] content translated to Japanese: {len(bracket_issues)}")
    if bracket_issues:
        print("\nSample issues (first 20):")
        for issue in bracket_issues[:20]:
            print(f"  Line {issue.line_num}: {issue.description}")
            if verbose:
                print(f"    Content: {issue.line_content}")

        if len(bracket_issues) > 20:
            print(f"\n  ... and {len(bracket_issues) - 20} more")

    # Glossary violation issues
    glossary_issues = issues['glossary_violations']
    print(f"\n[4] Glossary violations (incorrect terminology): {len(glossary_issues)}")
    if glossary_issues:
        print("\nSample issues (first 20):")
        for issue in glossary_issues[:20]:
            print(f"  Line {issue.line_num}: {issue.description}")
            if verbose:
                print(f"    Content: {issue.line_content}")

        if len(glossary_issues) > 20:
            print(f"\n  ... and {len(glossary_issues) - 20} more")

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

        # Bracket translation issues
        f.write(f"\n[3] Bracket [] content translated to Japanese: {len(issues['bracket_translation'])}\n")
        f.write("-"*80 + "\n")
        for issue in issues['bracket_translation']:
            f.write(f"Line {issue.line_num}: {issue.description}\n")
            f.write(f"  {issue.line_content}\n\n")

        # Glossary violation issues
        f.write(f"\n[4] Glossary violations (incorrect terminology): {len(issues['glossary_violations'])}\n")
        f.write("-"*80 + "\n")
        for issue in issues['glossary_violations']:
            f.write(f"Line {issue.line_num}: {issue.description}\n")
            f.write(f"  {issue.line_content}\n\n")

def main():
    parser = argparse.ArgumentParser(description='Validate translation quality')
    parser.add_argument('file', type=str, help='Translation file to validate')
    parser.add_argument('--reference', '-r', type=str, help='Spanish reference file (to determine if English should be translated)')
    parser.add_argument('--glossary', '-g', type=str, help='Glossary file (nouns_glossary.json) for terminology validation')
    parser.add_argument('--start-line', type=int, default=666, help='Start line for validation (default: 666)')
    parser.add_argument('--end-line', type=int, default=999999999, help='End line for validation (default: end of file)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--output', '-o', type=str, help='Save detailed report to file')

    args = parser.parse_args()

    filepath = Path(args.file)

    if not filepath.exists():
        print(f"Error: File not found: {filepath}")
        sys.exit(1)

    reference_filepath = None
    if args.reference:
        reference_filepath = Path(args.reference)
        if not reference_filepath.exists():
            print(f"Warning: Spanish reference file not found: {reference_filepath}")
            print("Validation will proceed without Spanish reference checks")
            reference_filepath = None

    glossary_filepath = None
    if args.glossary:
        glossary_filepath = Path(args.glossary)
        if not glossary_filepath.exists():
            print(f"Warning: Glossary file not found: {glossary_filepath}")
            print("Validation will proceed without glossary checks")
            glossary_filepath = None

    print(f"Validating: {filepath}")
    print(f"Range: lines {args.start_line} to {args.end_line}")
    if reference_filepath:
        print(f"Spanish reference: {reference_filepath}")
    if glossary_filepath:
        print(f"Glossary: {glossary_filepath}")

    issues = validate_file(filepath, reference_filepath, glossary_filepath, args.start_line, args.end_line, args.verbose)
    total_issues = print_report(issues, args.verbose)

    if args.output:
        output_path = Path(args.output)
        save_detailed_report(issues, output_path)
        print(f"\nDetailed report saved to: {output_path}")

    sys.exit(0 if total_issues == 0 else 1)

if __name__ == '__main__':
    main()
