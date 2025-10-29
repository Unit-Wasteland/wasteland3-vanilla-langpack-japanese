# Re-translation Workflow (翻訳やり直しワークフロー)

## 概要

このドキュメントは、構造破壊が発生したファイルを完全にやり直すためのワークフローを定義します。

### 背景

**完全再起動の理由（2回目）:**
自動翻訳処理の結果、77,533件の構造エラー（全エントリの45.7%）が発生し、Unity StringTableの構造マーカー（`""`）が日本語括弧（`「」`, `『』`）に変換されたり、引用符が不正に追加・削除されたりして、ファイルがゲームにインポート不可能になりました。

**問題の例:**
- 破損: `string data = "「日本語テキスト」"` (括弧変換)
- 破損: `string data = ""English text""` (不要な引用符追加)
- 破損: `string data = "Quoted text"` (引用符不足)
- 正常: `string data = ""日本語テキスト""` (Unity形式)

### 解決方針（厳格ワークフロー）

1. **英語ファイルを新しいベース**として使用（構造100%保証）
2. **スペイン語ファイルで翻訳可否を判断**（プログラム識別子の確実な識別）
3. **各編集後に検証**（構造破壊の即座検出・修正）
4. **シーケンシャル処理**（スキップ禁止、優先度付け禁止）
5. **バッチ処理厳格禁止**（品質保証のため手動・個別処理のみ）

**参照ドキュメント:**
- **translation/STRICT_TRANSLATION_RULES.md** - 厳格翻訳ルール（包括的ガイド）
- **translation/STRUCTURE_PROTECTION_RULES.md** - 構造保護ルール（詳細）
- **translation/validate_structure_v2.py** - 構造検証スクリプト（必須ツール）

## ファイル構成

```
translation/
├── source/v1.6.9.420.309496/
│   ├── en_US/              # 英語ソース（構造リファレンス・新ベース）
│   │   ├── StringTableData_English-CAB-*.txt (530,425行、169,712エントリ)
│   │   ├── DLC1/StringTableData_English-CAB-*.txt (120,559行)
│   │   └── DLC2/StringTableData_English-CAB-*.txt (77,353行)
│   └── es_ES/              # スペイン語（翻訳可否判断用・MANDATORY）
│       ├── StringTableData_Spanish-CAB-*.txt (530,425行)
│       ├── DLC1/StringTableData_Spanish-CAB-*.txt (120,559行)
│       └── DLC2/StringTableData_Spanish-CAB-*.txt (77,353行)
├── target/v1.6.9.420.309496/ja_JP/
│   ├── StringTableData_English-CAB-*.txt  # 作業対象ファイル（英語からコピー済み）
│   ├── DLC1/
│   └── DLC2/
├── backup_broken/          # 壊れた日本語訳（参考程度、使用推奨せず）
│   ├── StringTableData_English-CAB-*.txt (77,533構造エラーあり)
│   ├── DLC1/
│   └── DLC2/
├── nouns_glossary.json     # 用語集（英語→日本語）
├── .retranslation_progress.json  # 進捗管理ファイル（v3.0）
├── STRICT_TRANSLATION_RULES.md   # 厳格翻訳ルール（包括的ガイド）
├── STRUCTURE_PROTECTION_RULES.md # 構造保護ルール（詳細）
├── RETRANSLATION_WORKFLOW.md     # このファイル（ワークフロー概要）
└── validate_structure_v2.py      # 構造検証スクリプト（必須）
```

## ワークフローステップ

### Phase 0: 環境準備（手動実行、1回のみ）

```bash
# 1. 現在のtargetファイルをbackup_brokenに移動（完了済み）
# mkdir -p translation/backup_broken
# mv translation/target/v1.6.9.420.309496/ja_JP/* translation/backup_broken/

# 2. 英語ファイルを新しいベースとしてコピー
cp -r translation/source/v1.6.9.420.309496/en_US/* \
      translation/target/v1.6.9.420.309496/ja_JP/

# 3. 進捗管理ファイルの初期化
cat > translation/.retranslation_progress.json << 'EOF'
{
  "workflow_version": "2.0",
  "workflow_name": "retranslation",
  "start_date": "2025-10-22",
  "base_language": "en_US",
  "target_language": "ja_JP",
  "total_files": 3,
  "files": {
    "base_game": {
      "source_file": "translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt",
      "target_file": "translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt",
      "backup_file": "translation/backup_broken/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt",
      "total_lines": 530425,
      "total_entries_estimated": 51853,
      "current_line": 666,
      "entries_completed": 0,
      "status": "in_progress"
    },
    "dlc1": {
      "source_file": "translation/source/v1.6.9.420.309496/en_US/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt",
      "target_file": "translation/target/v1.6.9.420.309496/ja_JP/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt",
      "backup_file": "translation/backup_broken/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt",
      "total_lines": 120559,
      "total_entries_estimated": 12785,
      "current_line": 0,
      "entries_completed": 0,
      "status": "pending"
    },
    "dlc2": {
      "source_file": "translation/source/v1.6.9.420.309496/en_US/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt",
      "target_file": "translation/target/v1.6.9.420.309496/ja_JP/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt",
      "backup_file": "translation/backup_broken/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt",
      "total_lines": 77353,
      "total_entries_estimated": 7354,
      "status": "pending"
    }
  },
  "last_commit_hash": "",
  "total_entries_completed": 0,
  "estimated_total_entries": 71992,
  "next_action": "Process base_game starting from line 666"
}
EOF

# 4. gitコミット
git add translation/target/v1.6.9.420.309496/ja_JP/ \
         translation/.retranslation_progress.json \
         translation/RETRANSLATION_WORKFLOW.md \
         translation/STRUCTURE_PROTECTION_RULES.md
git commit -m "Initialize retranslation workflow: copy English files as new base

Preparation for complete retranslation with structure protection:
- Copied en_US files to ja_JP as new base (preserves structure)
- Created .retranslation_progress.json for progress tracking
- Added RETRANSLATION_WORKFLOW.md with detailed workflow
- Added STRUCTURE_PROTECTION_RULES.md with strict rules

Total scope: 71,992 entries (base game + DLC1 + DLC2)
Strategy: Extract Japanese from backup_broken, apply with structure protection

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Phase 1: 翻訳処理（厳格ワークフロー）

**⚠️ 重要: 必ずSTRICT_TRANSLATION_RULES.mdを参照してください**

**処理方式（厳格ルール）:**

1. **シーケンシャル処理（MANDATORY）**
   - 現在の行位置（.retranslation_progress.json参照）から順番に処理
   - スキップ禁止、優先度付け禁止、長文優先禁止
   - 1行ずつ確実に処理

2. **スペイン語参照による翻訳可否判断（MANDATORY）**
   - 各エントリを翻訳する前に、スペイン語ファイルの同じ行を確認
   - スペイン語で翻訳されている → 日本語でも翻訳可能
   - スペイン語で英語のまま/空 → プログラム識別子なので英語のまま残す
   - 例: "Script Node 65" はスペイン語でも英語 → 翻訳禁止

3. **構造保護（MANDATORY）**
   - Unity形式: `string data = ""日本語テキスト""` (引用符4個)
   - `\"` エスケープ使用禁止（Unity形式では不要）
   - 日本語括弧（「」『』）使用禁止
   - [Global:], [Dropset:], ::action:: 絶対に翻訳禁止

4. **各編集後の検証（MANDATORY）**
   ```bash
   ./translation/validate_structure_v2.py \
     translation/target/.../ja_JP/StringTableData_*.txt \
     --source translation/source/.../en_US/StringTableData_*.txt \
     --detailed
   ```
   - エラーが1件でもあれば即座に修正
   - 引用符の数が英語ソースと完全一致していることを確認

5. **用語集参照**
   - nouns_glossary.jsonを参照して一貫した訳語を使用
   - キャラクター名、地名、派閥名などの固有名詞

**具体的な処理ロジック（Claude Codeが実行）:**

```
⚠️ 重要: backup_brokenからの抽出は行わない。ゼロから新規翻訳する。

FOR each file in [base_game, dlc1, dlc2]:
  progress = load_progress_from_json()
  current_line = progress.current_line

  WHILE current_line < total_lines:
    # 1. 150-200行チャンクを読み込み（メモリ効率化）
    english_chunk = Read(english_source_file, offset=current_line, limit=150)
    spanish_chunk = Read(spanish_source_file, offset=current_line, limit=150)
    target_chunk = Read(target_file, offset=current_line, limit=150)

    # 2. 各エントリを個別に処理（バッチ処理禁止）
    FOR each line_num, line in enumerate(chunk):
      IF line contains 'string data = ':
        # ステップA: スペイン語で翻訳可否を判断
        spanish_line = spanish_chunk[line_num]
        english_text = extract_text_only(english_chunk[line_num])
        spanish_text = extract_text_only(spanish_line)

        IF spanish_text == english_text OR spanish_text is empty:
          # プログラム識別子 → 翻訳禁止
          # (例: "Script Node 65", "[Global: A1001_Test]")
          CONTINUE  # 英語のまま残す
        ELSE:
          # 翻訳可能 → 日本語に翻訳
          japanese_text = translate_with_glossary(english_text, nouns_glossary.json)

        # ステップB: 構造を保護しながら適用
        structure = extract_structure_with_quotes(target_chunk[line_num])
        new_line = apply_japanese_preserving_structure(structure, japanese_text)

        # ステップC: 編集実行
        Edit(target_file, old_line=target_chunk[line_num], new_line=new_line)

        # ステップD: 即座に検証（MANDATORY）
        validation_result = run_validate_structure_v2(target_file, english_source_file)
        IF validation_result.errors > 0:
          ERROR("構造破壊を検出 - 即座に修正が必要")
          # 前の状態にロールバック
          Edit(target_file, old_line=new_line, new_line=target_chunk[line_num])
          HALT  # 問題解決まで停止

        entries_completed += 1

    current_line += 150

    # 5. 500エントリごとにコミット
    IF entries_completed % 500 == 0:
      git_commit_with_progress()
      update_progress_json(current_line, entries_completed)
      PUSH to remote  # データ損失防止

    # 6. メモリチェック
    IF memory_usage > 5000MB:
      WARNING("Memory threshold reached - session end")
      commit_immediately()
      EXIT  # 自動化スクリプトが新セッション開始

  END WHILE
END FOR
```

**禁止事項（厳格）:**
- ❌ backup_brokenからの抽出（構造が破損しているため）
- ❌ バッチ処理（品質保証のため個別処理のみ）
- ❌ スペイン語参照のスキップ（誤翻訳防止）
- ❌ 検証のスキップ（構造破壊即座検出が必須）
- ❌ 行のスキップや優先度付け（完全性保証）

### Phase 2: 品質検証（自動実行）

**検証項目:**

```bash
# 1. 行数一致確認
wc -l translation/source/v1.6.9.420.309496/en_US/*.txt \
      translation/target/v1.6.9.420.309496/ja_JP/*.txt

# 2. 構造マーカー検証（破損チェック）
# 破損パターンが存在しないことを確認
! grep 'string data = "「' translation/target/v1.6.9.420.309496/ja_JP/*.txt
! grep 'string data = "『' translation/target/v1.6.9.420.309496/ja_JP/*.txt

# 3. 正常パターン確認
grep -c 'string data = "".*[ぁ-ん].*""' translation/target/v1.6.9.420.309496/ja_JP/*.txt

# 4. 中国語混入チェック
# （簡体字の範囲: \u4e00-\u9fa5 のうち日本語で使われないもの）
# 手動で確認が必要

# 5. アクションマークアップ検証
grep 'string data = ""::' translation/target/v1.6.9.420.309496/ja_JP/*.txt | \
  grep -v '::[a-z]*::' && echo "ERROR: Invalid action markup found"

# 6. Script Node検証（翻訳されていないことを確認）
! grep 'string data = ""スクリプトノード' translation/target/v1.6.9.420.309496/ja_JP/*.txt
```

## メモリ管理戦略

### チャンクサイズとコミット頻度

| 設定項目 | 値 | 理由 |
|---------|---|-----|
| **read_chunk_size** | 50行 | 2025-10-22のheap OOM後、安全側に調整 |
| **max_chunk_size** | 100行 | 絶対に超えてはいけない上限 |
| **batch_size** | 50エントリ | 処理サイクルあたりの処理数 |
| **commit_frequency** | 100エントリ | コミット間隔（メモリ圧力軽減） |
| **memory_warning** | 4GB | 警告閾値（チャンクサイズ縮小） |
| **memory_limit** | 6GB | 強制再起動閾値 |

### セッション再起動戦略

自動化スクリプト（`automation/auto-retranslate.sh`）が処理:
- 2,000-3,000エントリごとにメモリチェック
- 4GB到達で警告、チャンクサイズを25行に縮小
- 6GB到達でセッション再起動
- 進捗ファイルから自動復帰

## 自動化スクリプト

### 起動方法

```bash
# 完全自動実行（推奨）
./automation/auto-retranslate.sh

# 手動セッション（テスト・デバッグ用）
claude
# 以下を入力:
# translation/.retranslation_progress.json を読み込んで、
# translation/RETRANSLATION_WORKFLOW.md に従って翻訳やり直し作業を継続してください。
```

### スクリプト動作

```bash
# 疑似コード
while true; do
  # 1. Claude Codeセッション起動
  start_claude_session_with_permissions()

  # 2. 進捗ファイル読み込みと処理実行
  execute_retranslation_workflow()

  # 3. 進捗確認
  entries_completed_this_session = check_progress()

  # 4. 完了判定
  if all_files_completed; then
    echo "✅ 全翻訳やり直し完了！"
    exit 0
  fi

  # 5. エラー検出
  if entries_completed_this_session == 0; then
    consecutive_zero_sessions++
    if consecutive_zero_sessions >= 3; then
      echo "❌ エラー: 3連続で進捗なし"
      exit 1
    fi
  else
    consecutive_zero_sessions=0
  fi

  # 6. メモリチェックと再起動
  sleep 60  # 次セッション前のクールダウン
done
```

## トラブルシューティング

### 問題1: 構造マーカーが破損している

**検出方法:**
```bash
grep 'string data = "「' translation/target/v1.6.9.420.309496/ja_JP/*.txt
```

**原因:**
- 構造保護ロジックの不具合
- Claude Codeが意図せず日本語括弧を使用

**解決方法:**
1. 該当セクションのgit revert
2. 構造保護ルールを再確認
3. より小さいチャンク（25行）で再実行

### 問題2: メモリ不足でクラッシュ

**検出方法:**
- Node.js heap out of memory エラー
- セッションが応答しなくなる

**解決方法:**
1. 進捗ファイルから最後の成功点を確認
2. チャンクサイズを25行に縮小
3. コミット頻度を50エントリに増加
4. セッション再起動

### 問題3: 翻訳品質が低い

**検出方法:**
- 中国語（簡体字）が混入
- 用語集と異なる訳語が使用されている

**解決方法:**
1. nouns_glossary.jsonを確認・更新
2. 該当エントリを手動修正
3. git commitで記録

### 問題4: 進捗が停止している

**検出方法:**
```bash
tail -100 automation/retranslation-automation.log
```

**原因:**
- 3連続でentries_completed == 0
- 権限承認でブロック
- 予期しないエラー

**解決方法:**
1. ログファイルで原因特定
2. 手動セッションでデバッグ
3. 問題解決後、自動化スクリプト再起動

## 進捗の確認

```bash
# 現在の進捗状況
cat translation/.retranslation_progress.json | jq '.total_entries_completed, .estimated_total_entries'

# 完了率計算
echo "scale=2; $(jq '.total_entries_completed' translation/.retranslation_progress.json) * 100 / $(jq '.estimated_total_entries' translation/.retranslation_progress.json)" | bc

# 最近のコミット
git log --oneline --grep="retranslation" -10

# ファイルごとの進捗
cat translation/.retranslation_progress.json | jq '.files'
```

## 完了後の確認事項

- [ ] 全ファイルの行数が元ファイルと一致
- [ ] 破損した構造マーカーが0件
- [ ] 正常な日本語エントリ数が71,992件（またはそれに近い）
- [ ] 中国語混入なし
- [ ] アクションマークアップが全て英語のまま
- [ ] Script Nodeが翻訳されていない
- [ ] Git履歴に全コミットが記録されている
- [ ] nouns_glossary.jsonに準拠した訳語が使用されている

## 関連ドキュメント

- `translation/STRUCTURE_PROTECTION_RULES.md` - 構造保護の厳格なルール
- `translation/nouns_glossary.json` - 用語集
- `automation/README.md` - 自動化システムの詳細
- `CLAUDE.md` - プロジェクト全体の概要
