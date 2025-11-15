# 未翻訳エントリ修正作業 - セッション再開用メモ

## 現在の進捗（2025-11-15）

### 完了した作業
- **翻訳完了エントリ数: 73個**
- コミット: 05774d97
- 構造検証: ✅ エラー0件

### 未翻訳エントリの状況

#### 総検出数: 1,439個
スクリプトで検出された「未翻訳」エントリのうち、実際に翻訳が必要なのは一部のみ。

#### 除外すべきエントリ（翻訳不要）
- 16進数データ（機械コード）: 例 "4f 6b 61 79..."
- ASCIIアート: 例 "(╯°□°）╯︵ ┻┻"
- "DO NOT TRANSLATE"明記エントリ
- 省略記号のみ: "...", "…"
- 単一文字: "I."
- 技術的コード: "7A?", "13C"
- 日付: "2102.08.26"
- デバッグテキスト

#### 翻訳済みの範囲
- Lines 136332-209374: NPCダイアログ、システムメッセージ
- Lines 211510-221298: 機械知性体の会話
- その他散在するエントリ

## 次回セッション開始手順

### 1. 残りの未翻訳エントリを取得

```bash
# 最新の未翻訳リストを再生成
python3 << 'PYEOF'
import re

target_file = "/home/user/project_claude/game_wasteland/wasteland3-vanilla-langpack-japanese/translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"

real_untranslated = []

with open(target_file, 'r', encoding='utf-8') as f:
    for line_num, line in enumerate(f, 1):
        if 'string data = ""' in line:
            match = re.search(r'string data = ""(.*)""', line)
            if match:
                content = match.group(1)
                if not content:
                    continue
                if content.startswith('Script Node') or content.startswith('Trigger Conv Node'):
                    continue
                if content.startswith('[Global:') or content.startswith('[Switch to'):
                    continue
                if re.match(r'^::.*::$', content.strip()):
                    continue
                if re.search(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]', content):
                    continue

                # 除外パターン
                if re.match(r'^\.\.\.+$', content) or re.match(r'^…+$', content):
                    continue
                if re.match(r'^[A-Z]\.?$', content):
                    continue
                if re.match(r'^[01]+\.\.\.$', content):
                    continue
                if re.match(r'^[0-9]{2,4}\.[0-9]{2}\.[0-9]{2,4}$', content):
                    continue
                if re.match(r'^z+\.\.\.$', content):
                    continue
                if 'DEBUG' in content.upper():
                    continue
                if 'DO NOT TRANSLATE' in content:
                    continue

                # 意味のあるテキストのみ
                if len(content) >= 10 or ' ' in content:
                    real_untranslated.append((line_num, content))

print(f"Total remaining untranslated entries: {len(real_untranslated)}")
print("\nFirst 20 entries:")
for line_num, content in real_untranslated[:20]:
    print(f"Line {line_num}: {content[:80]}")
PYEOF
```

### 2. 翻訳作業の続行

次回は残りのエントリを200個目標で翻訳：

```bash
claude
# メッセージ: "RESUME_UNTRANSLATED_FIX.mdを確認して、未翻訳エントリの翻訳を続けてください。200エントリ完了を目標に作業します。"
```

### 3. 作業パターン

1. 10-20エントリずつ翻訳
2. 各バッチ後に検証:
   ```bash
   python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_FILE
   ```
3. 構造エラー0件を確認
4. 定期的にコミット（50-100エントリごと）

## 使用ファイル・パス

### 対象ファイル
- **ターゲット**: `translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt`
- **ソース（英語）**: `translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt`

### 検証スクリプト
- 構造検証: `translation/validate_structure_v2.py`
- 品質検証: `translation/validate_translation_quality.py`

### 用語集
- `translation/nouns_glossary.json` - 固有名詞の統一表記

## 重要な注意事項

### 翻訳してはいけないもの
1. `Script Node X` - そのまま残す
2. `[Global:...]`, `[Switch to...]` - そのまま残す
3. `::action::` - アクションマーカーは英語のまま
4. "DO NOT TRANSLATE" 明記エントリ
5. 16進数データ、ASCIIアート

### 構造保護ルール
- `""` の数を必ず一致させる
- `[]`, `<>` のタグを保持
- `\n`, `\r`, `\t` などのエスケープシーケンスを保持

## 次回目標
- 残りのエントリから200個翻訳完了
- 全体で273個翻訳済みにする（73 + 200）
- 構造エラー0件を維持
