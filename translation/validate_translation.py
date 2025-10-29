#!/usr/bin/env python3
"""
翻訳検証スクリプト - 改善版
未翻訳箇所を検出し、セクションごとの完了率を報告します。

使用方法:
  ./validate_translation.py <target_file> [--start-line START] [--end-line END] [--detailed]

オプション:
  --start-line START  : 検証開始行（デフォルト: 1）
  --end-line END      : 検証終了行（デフォルト: ファイル末尾）
  --detailed          : 未翻訳エントリの詳細リストを表示
  --export FILE       : 未翻訳箇所をファイルにエクスポート
"""

import re
import sys
import argparse
from typing import List, Tuple, Dict

def is_technical_term(text: str) -> bool:
    """技術用語や翻訳不要なマーカーかチェック"""
    technical_patterns = [
        r'^Script Node \d+$',
        r'^Trigger Conv Node \d+$',
        r'DEBUG',
        r'\[Switch to ',
        r'\[Reward:',
        r'\[Global:',
        r'Dropset',
        r'^::.*::$',  # Action markup only
        r'^[A-Z][A-Z_]+$',  # All caps technical terms
    ]

    for pattern in technical_patterns:
        if re.search(pattern, text):
            return True
    return False

def is_likely_untranslated(text: str) -> bool:
    """実際の会話文や説明文で未翻訳の可能性が高いかチェック"""
    # Empty or technical terms are not untranslated
    if not text or is_technical_term(text):
        return False

    # Check for English content
    english_words = re.findall(r'\b[A-Za-z]+\b', text)

    # If starts with capital letter and has many English words, likely untranslated
    if re.match(r'^[A-Z]', text) and len(english_words) > 5:
        return True

    # If text is mostly English (more than 10 English words)
    if len(english_words) > 10:
        return True

    # Check for development placeholders
    if text in ['Test', 'TBD', 'TODO']:
        return True

    return False

def validate_translation_file(
    file_path: str,
    start_line: int = 1,
    end_line: int = None,
    detailed: bool = False
) -> Dict:
    """翻訳ファイルを検証し、未翻訳箇所を検出"""

    results = {
        'total_entries': 0,
        'empty_entries': 0,
        'translated': 0,
        'untranslated': 0,
        'untranslated_list': [],
        'technical_terms': 0
    }

    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            # Skip lines outside range
            if line_num < start_line:
                continue
            if end_line and line_num > end_line:
                break

            if 'string data = ' not in line:
                continue

            results['total_entries'] += 1

            # Check for double-quote format: string data = ""text""
            match_double = re.search(r'string data = ""([^"]*)""', line)
            if match_double:
                text = match_double.group(1)

                if not text:  # Empty string
                    results['empty_entries'] += 1
                    results['translated'] += 1  # Empty is considered "complete"
                elif is_technical_term(text):
                    results['technical_terms'] += 1
                    results['translated'] += 1  # Technical terms are correct as-is
                elif is_likely_untranslated(text):
                    results['untranslated'] += 1
                    results['untranslated_list'].append((line_num, text[:100]))
                else:
                    results['translated'] += 1

            # Check for single-quote format: string data = " text"
            match_single = re.search(r'string data = " ([^"]*)"', line)
            if match_single:
                text = match_single.group(1)
                # Single-quote with English might be untranslated
                if re.search(r'[A-Za-z]{3,}', text) and not is_technical_term(text):
                    # Check if it's a placeholder or actual untranslated content
                    if text.startswith('I ') or text.startswith('Talk to ') or 'TODO' in text:
                        results['untranslated'] += 1
                        results['untranslated_list'].append((line_num, text[:100]))

    return results

def print_results(results: Dict, detailed: bool = False):
    """検証結果を表示"""
    total = results['total_entries']
    translated = results['translated']
    untranslated = results['untranslated']
    completion_rate = (translated / total * 100) if total > 0 else 0

    print("=" * 60)
    print("翻訳検証結果")
    print("=" * 60)
    print(f"総エントリ数: {total:,}")
    print(f"  - 翻訳済み: {translated:,}")
    print(f"  - 未翻訳: {untranslated:,}")
    print(f"  - 空文字列: {results['empty_entries']:,}")
    print(f"  - 技術用語: {results['technical_terms']:,}")
    print(f"\n完了率: {completion_rate:.2f}%")

    if untranslated > 0:
        print(f"\n⚠️  警告: {untranslated}件の未翻訳箇所があります")

        if detailed and results['untranslated_list']:
            print("\n未翻訳エントリ一覧（最初の50件）:")
            print("-" * 60)
            for line_num, text in results['untranslated_list'][:50]:
                print(f"{line_num:6d}: {text}")
    else:
        print("\n✓ このセクションは100%完了しています")

    print("=" * 60)

def export_untranslated(results: Dict, output_file: str):
    """未翻訳箇所をファイルにエクスポート"""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# 未翻訳箇所リスト\n\n")
        f.write(f"総数: {results['untranslated']}件\n\n")

        for line_num, text in results['untranslated_list']:
            f.write(f"Line {line_num}: {text}\n")

    print(f"\n未翻訳箇所を {output_file} にエクスポートしました")

def main():
    parser = argparse.ArgumentParser(
        description='翻訳ファイルの検証 - 未翻訳箇所を検出',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('file', help='検証する翻訳ファイル')
    parser.add_argument('--start-line', type=int, default=1, help='検証開始行')
    parser.add_argument('--end-line', type=int, help='検証終了行')
    parser.add_argument('--detailed', action='store_true', help='詳細表示')
    parser.add_argument('--export', help='未翻訳箇所のエクスポート先ファイル')

    args = parser.parse_args()

    # Validation
    try:
        results = validate_translation_file(
            args.file,
            start_line=args.start_line,
            end_line=args.end_line,
            detailed=args.detailed
        )

        # Print results
        print_results(results, detailed=args.detailed)

        # Export if requested
        if args.export:
            export_untranslated(results, args.export)

        # Exit with error code if untranslated entries found
        sys.exit(1 if results['untranslated'] > 0 else 0)

    except FileNotFoundError:
        print(f"エラー: ファイルが見つかりません: {args.file}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"エラー: {e}", file=sys.stderr)
        sys.exit(2)

if __name__ == '__main__':
    main()
