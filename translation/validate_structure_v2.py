#!/usr/bin/env python3
"""
Unity StringTable構造検証スクリプト v2.0

このスクリプトは英語ソースと日本語ターゲットを厳密に比較します:
- 行数の一致
- 各行の引用符の数の一致
- ゲーム変数の保持確認

使用方法:
  ./validate_structure_v2.py <target_file> --source <source_file> [--detailed]
"""

import re
import sys
import argparse
from typing import List, Tuple, Dict

class StrictStructureValidator:
    def __init__(self, target_file: str, source_file: str):
        self.target_file = target_file
        self.source_file = source_file
        self.errors = []
        self.warnings = []

    def validate(self) -> Dict:
        """厳格な構造検証を実行"""
        results = {
            'total_lines': 0,
            'string_data_lines': 0,
            'errors': [],
            'warnings': [],
            'error_count': 0,
            'warning_count': 0
        }

        # ファイル読み込み
        try:
            with open(self.source_file, 'r', encoding='utf-8') as f:
                source_lines = f.readlines()
        except FileNotFoundError:
            print(f"エラー: ソースファイルが見つかりません: {self.source_file}", file=sys.stderr)
            return results

        try:
            with open(self.target_file, 'r', encoding='utf-8') as f:
                target_lines = f.readlines()
        except FileNotFoundError:
            print(f"エラー: ターゲットファイルが見つかりません: {self.target_file}", file=sys.stderr)
            return results

        # 行数の一致確認
        if len(source_lines) != len(target_lines):
            results['errors'].append({
                'line': 0,
                'type': 'LINE_COUNT_MISMATCH',
                'message': f'行数不一致: ソース={len(source_lines)}, ターゲット={len(target_lines)}',
                'content': f'差分: {len(target_lines) - len(source_lines)} 行'
            })
            results['error_count'] += 1
            return results

        results['total_lines'] = len(source_lines)

        # 各行を検証
        for i, (src_line, tgt_line) in enumerate(zip(source_lines, target_lines), 1):
            if 'string data = ' not in src_line:
                continue

            results['string_data_lines'] += 1

            # CLAUDE.md厳格ルール: クォート数を英語ソースと一致させる
            # - 英語が `string data = " text"` (2個) → 日本語も `string data = " text"` (2個)
            # - 英語が `string data = ""text""` (4個) → 日本語も `string data = ""text""` (4個)
            # - クォートの追加・削除禁止
            # - エスケープ `\"` 禁止

            # クォート数を数える
            src_quote_count = src_line.count('"')
            tgt_quote_count = tgt_line.count('"')

            # エスケープシーケンス検出
            if '\\"' in tgt_line or "\\'" in tgt_line:
                results['errors'].append({
                    'line': i,
                    'type': 'ESCAPE_SEQUENCE_FORBIDDEN',
                    'message': 'エスケープシーケンス検出（絶対禁止 - 構造破壊の原因）',
                    'target': tgt_line.strip()[:100]
                })

            # クォート数の一致確認
            if src_quote_count != tgt_quote_count:
                results['errors'].append({
                    'line': i,
                    'type': 'QUOTE_COUNT_MISMATCH',
                    'message': f'クォート数不一致: ソース={src_quote_count}, ターゲット={tgt_quote_count}',
                    'source': src_line.strip()[:80],
                    'target': tgt_line.strip()[:80]
                })

            # ゲーム変数の保持確認
            self._check_game_variables(src_line, tgt_line, i, results)

            # 特殊マーカーの保持確認
            self._check_special_markers(src_line, tgt_line, i, results)

        results['error_count'] = len(results['errors'])
        results['warning_count'] = len(results['warnings'])

        return results

    def _check_game_variables(self, src_line: str, tgt_line: str, line_num: int, results: Dict):
        """ゲーム変数が保持されているか確認"""

        # [Global: ...] パターン
        global_vars = re.findall(r'\[Global: [A-Za-z0-9_]+\]', src_line)
        for var in global_vars:
            if var not in tgt_line:
                results['errors'].append({
                    'line': line_num,
                    'type': 'GAME_VARIABLE_MISSING',
                    'message': f'ゲーム変数が欠けている: {var}',
                    'source': src_line.strip()[:80],
                    'target': tgt_line.strip()[:80]
                })

        # [Dropset: ...] パターン
        dropset_vars = re.findall(r'\[Dropset: [A-Za-z0-9_]+\]', src_line)
        for var in dropset_vars:
            if var not in tgt_line:
                results['errors'].append({
                    'line': line_num,
                    'type': 'DROPSET_MISSING',
                    'message': f'Dropset変数が欠けている: {var}',
                    'source': src_line.strip()[:80],
                    'target': tgt_line.strip()[:80]
                })

    def _check_special_markers(self, src_line: str, tgt_line: str, line_num: int, results: Dict):
        """特殊マーカーが保持されているか確認"""

        # Script Node は翻訳禁止
        if 'Script Node' in src_line and 'Script Node' not in tgt_line:
            results['errors'].append({
                'line': line_num,
                'type': 'SCRIPT_NODE_TRANSLATED',
                'message': 'Script Nodeが翻訳されています（翻訳禁止）',
                'source': src_line.strip()[:80],
                'target': tgt_line.strip()[:80]
            })

        # []内に日本語が含まれていないか確認（技術的なマーカーは翻訳禁止）
        # 例外: [[Global: ...] UNIT]のような入れ子構造で単位語（Dollars→ドル等）は翻訳可
        if 'string data' in tgt_line:
            # Extract string data content
            content_match = re.search(r'string data = ""(.*)""', tgt_line)
            if content_match:
                content = content_match.group(1)
                # Find all individual bracket pairs (non-nested)
                single_bracket_pattern = re.compile(r'\[([^\[\]]+)\]')
                japanese_char_pattern = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]')

                for bracket_match in single_bracket_pattern.finditer(content):
                    bracket_content = bracket_match.group(1)

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
                    if is_technical_marker and japanese_char_pattern.search(bracket_content):
                        results['errors'].append({
                            'line': line_num,
                            'type': 'BRACKET_CONTENT_TRANSLATED',
                            'message': f'技術的マーカーが日本語に翻訳されています（翻訳禁止）: [{bracket_content}]',
                            'source': src_line.strip()[:80],
                            'target': tgt_line.strip()[:80]
                        })

        # HTMLタグの確認
        src_tags = re.findall(r'<[^>]+>', src_line)
        for tag in src_tags:
            if tag not in tgt_line:
                results['warnings'].append({
                    'line': line_num,
                    'type': 'HTML_TAG_MISSING',
                    'message': f'HTMLタグが欠けている: {tag}',
                    'source': src_line.strip()[:80],
                    'target': tgt_line.strip()[:80]
                })

def print_results(results: Dict, detailed: bool = False):
    """検証結果を表示"""
    print("=" * 80)
    print("Unity StringTable 厳格構造検証結果 v2.0")
    print("=" * 80)
    print(f"総行数: {results['total_lines']:,}")
    print(f"string data行数: {results['string_data_lines']:,}")
    print(f"\nエラー: {results['error_count']}件")
    print(f"警告: {results['warning_count']}件")

    if results['error_count'] == 0 and results['warning_count'] == 0:
        print("\n✓ 構造検証: 問題なし")
        print("✓ 全ての行で引用符の数が一致しています")
        print("✓ ゲーム変数が保持されています")
    else:
        if results['errors']:
            print("\n" + "=" * 80)
            print("エラー一覧:")
            print("=" * 80)

            # エラーをタイプ別に集計
            error_by_type = {}
            for error in results['errors']:
                error_type = error['type']
                if error_type not in error_by_type:
                    error_by_type[error_type] = []
                error_by_type[error_type].append(error)

            for error_type, errors in error_by_type.items():
                print(f"\n{error_type}: {len(errors)}件")
                if detailed:
                    for error in errors[:20]:  # 最初の20件
                        line = error['line']
                        msg = error['message']
                        print(f"  Line {line:6d}: {msg}")
                        if 'source' in error and error['source']:
                            print(f"    SRC: {error['source']}")
                        if 'target' in error and error['target']:
                            print(f"    TGT: {error['target']}")
                    if len(errors) > 20:
                        print(f"  ... 他{len(errors) - 20}件")

        if results['warnings']:
            print("\n" + "=" * 80)
            print("警告一覧:")
            print("=" * 80)

            # 警告をタイプ別に集計
            warning_by_type = {}
            for warning in results['warnings']:
                warning_type = warning['type']
                if warning_type not in warning_by_type:
                    warning_by_type[warning_type] = []
                warning_by_type[warning_type].append(warning)

            for warning_type, warnings in warning_by_type.items():
                print(f"\n{warning_type}: {len(warnings)}件")
                if detailed:
                    for warning in warnings[:10]:  # 最初の10件
                        line = warning['line']
                        msg = warning['message']
                        print(f"  Line {line:6d}: {msg}")
                        if 'source' in warning and warning['source']:
                            print(f"    SRC: {warning['source']}")
                        if 'target' in warning and warning['target']:
                            print(f"    TGT: {warning['target']}")
                    if len(warnings) > 10:
                        print(f"  ... 他{len(warnings) - 10}件")

    print("=" * 80)

def main():
    parser = argparse.ArgumentParser(
        description='Unity StringTable厳格構造検証スクリプト v2.0',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('file', help='検証する翻訳ファイル')
    parser.add_argument('--source', required=True, help='対応するソースファイル（必須）')
    parser.add_argument('--detailed', action='store_true', help='詳細表示')
    parser.add_argument('--export', help='問題箇所のエクスポート先ファイル')

    args = parser.parse_args()

    # 検証実行
    validator = StrictStructureValidator(args.file, args.source)
    results = validator.validate()

    # 結果表示
    print_results(results, detailed=args.detailed)

    # エクスポート
    if args.export and (results['errors'] or results['warnings']):
        with open(args.export, 'w', encoding='utf-8') as f:
            f.write("# Unity StringTable 厳格構造検証結果 v2.0\n\n")
            f.write(f"ターゲットファイル: {args.file}\n")
            f.write(f"ソースファイル: {args.source}\n")
            f.write(f"エラー: {results['error_count']}件\n")
            f.write(f"警告: {results['warning_count']}件\n\n")

            if results['errors']:
                f.write("## エラー\n\n")
                for error in results['errors']:
                    f.write(f"Line {error['line']}: {error['type']}\n")
                    f.write(f"  {error['message']}\n")
                    if 'source' in error:
                        f.write(f"  SRC: {error['source']}\n")
                    if 'target' in error:
                        f.write(f"  TGT: {error['target']}\n")
                    f.write("\n")

            if results['warnings']:
                f.write("## 警告\n\n")
                for warning in results['warnings']:
                    f.write(f"Line {warning['line']}: {warning['type']}\n")
                    f.write(f"  {warning['message']}\n")
                    if 'source' in warning:
                        f.write(f"  SRC: {warning['source']}\n")
                    if 'target' in warning:
                        f.write(f"  TGT: {warning['target']}\n")
                    f.write("\n")

        print(f"\n検証結果を {args.export} にエクスポートしました")

    # エラーがあれば終了コード1
    sys.exit(1 if results['error_count'] > 0 else 0)

if __name__ == '__main__':
    main()
