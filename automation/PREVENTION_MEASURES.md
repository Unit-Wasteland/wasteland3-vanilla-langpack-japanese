# 翻訳漏れ再発防止策

**作成日**: 2025-11-09
**問題**: Session R3-202で1つのエントリ（line 202826）が翻訳されずに残っていた
**影響**: 自動化システムが品質検証で停止、手動修正が必要に

---

## 実施した再発防止策

### 1. 自動修正システムの強化

#### 1.1 翻訳漏れ検出スクリプトの追加

**新規ファイル**: `automation/auto-fix-untranslated.py`

**重要**: このスクリプトは**検出のみ**を行い、自動翻訳は**行いません**

**理由**: CLAUDE.mdで以下が厳格に禁止されているため：
- ❌ バッチ処理
- ❌ スクリプトによる一括操作
- ❌ 自動化ショートカット
- ✅ シーケンシャル処理のみ許可
- ✅ 手動翻訳のみ許可

**機能**:
- 翻訳されていないエントリを検出
- リスト形式で報告（行番号と英語テキスト）
- 手動修正を促すメッセージを表示

**使用方法**:
```bash
python3 automation/auto-fix-untranslated.py TARGET_FILE SOURCE_FILE REFERENCE_FILE \
  --start-line 390 --end-line CURRENT_LINE \
  --glossary translation/nouns_glossary.json
```

**戻り値**:
- `0`: 翻訳漏れなし（問題なし）
- `1`: 翻訳漏れ検出（**手動修正が必要**）
- `2`: スクリプトエラー

#### 1.2 auto-fix-errors.shの拡張

**変更内容**:
- `detect_untranslated_entries()` 関数を追加（**検出のみ、修正はしない**）
- メインルーチンに翻訳漏れ検出を統合
- 検出時は自動で停止し、手動介入を促す

**重要な動作**:
- アクションマーカー → **自動修正可能**（既存機能）
- 翻訳漏れ → **検出のみ、自動修正不可**（CLAUDE.mdルール遵守）
- 翻訳漏れ検出時 → システム停止、手動修正を指示

**実行順序**:
1. アクションマーカー修正（自動）
2. **翻訳漏れ検出**（NEW - 検出のみ、修正は手動）
3. 構造エラー分析（将来実装予定）

### 2. セッション内検証の強化

#### 2.1 コマンドファイルの改善

**ファイル**: `automation/auto-retranslate.sh` (行459-490)

**強化内容**:

**各編集後の検証** (MANDATORY - ENHANCED 2025-11-09):

a) **構造検証** (既存):
```bash
python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_FILE --detailed
```
→ エラー数: 0 を確認

b) **アクションマーカー検証** (既存):
```bash
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
```
→ 結果が空であることを確認

c) **品質検証** (**NEW - 2025-11-09追加**):
```bash
python3 translation/validate_translation_quality.py TARGET_FILE \
  --reference REFERENCE_FILE \
  --start-line START_LINE \
  --end-line END_LINE \
  --glossary translation/nouns_glossary.json
```
→ **Total issues found: 0** を確認
→ 特に **"Untranslated English entries: 0"** を厳格に確認

**重要なルール**:
- ✅ **全ての検証が合格するまでコミットしない**
- ✅ **検証を1つでもスキップしてはならない**
- ✅ **「たぶん大丈夫」という推測は禁止**
- ✅ **必ず実際にスクリプトを実行して確認**

### 3. 自動化スクリプトの検証フロー改善

#### 3.1 品質検証の実行タイミング

**ファイル**: `automation/auto-retranslate.sh` (行638-700)

**フロー**:
1. セッション完了
2. **構造検証** → 失敗時: auto-fix実行
3. **品質検証** → 失敗時: auto-fix実行（**NEW**）
4. 両方合格 → git push

**auto-fix失敗時の動作**:
- バックアップファイルを保持
- 自動化を停止
- ログファイルに詳細を記録
- 手動介入を促す

---

## 期待される効果

### 即時効果
1. **翻訳漏れの早期検出**
   - セッション終了後すぐに検出
   - 詳細な行番号とテキストを報告

2. **CLAUDE.mdルールの厳格遵守**
   - バッチ処理を完全に排除
   - 全ての翻訳は手動で実施
   - シーケンシャル処理の徹底

3. **明確な修正指示**
   - 手動修正が必要なエントリをリスト表示
   - 修正手順を明示
   - 自動化システムを安全に停止

### 長期効果
1. **品質の向上**
   - 翻訳漏れゼロを目指す
   - 手動検証の徹底
   - CLAUDE.mdルールの完全遵守

2. **作業の透明性向上**
   - 全ての翻訳作業が追跡可能
   - バッチ処理なしで品質保証
   - 早期検出で手戻り最小化

---

## 今後の課題

### 1. より高度な自動翻訳

**現状**: 用語集マッチングのみ

**改善案**:
- Claude APIを使用した自動翻訳
- セッション内で即座に修正
- より複雑な対話も自動処理

### 2. 構造エラーの自動修正

**現状**: 検出のみ、修正は手動

**改善案**:
- 引用符数の自動修正
- エスケープシーケンスの自動修正
- より堅牢な修正アルゴリズム

### 3. リアルタイム検証

**現状**: 編集後にスクリプト実行

**改善案**:
- 編集中にリアルタイム検証
- エラーを即座にフィードバック
- プレコミットフックの活用

---

## テスト結果

### テストケース: line 202826 (Session R3-202エラー)

**エントリ内容**:
```
EN: "One moment. One moment. Well, either you made an incredibly lucky guess,
     or you are who you say you are. All right, I guess I'll have to trust you."
ES: "Un momento. Un momento. O bien habéis tenido mucha suerte,
     o sois quienes decís ser. Bueno, supongo que debo confiar en vosotros."
JA: (翻訳漏れ) → 手動修正済み
```

**検出スクリプト結果**:
- ✅ 翻訳漏れを正しく検出
- ✅ 行番号（202826）と英語テキストを報告
- ✅ "MANUAL translation required" メッセージを表示
- ✅ システムを安全に停止

**修正プロセス**:
1. 検出スクリプトが問題を発見
2. 自動化システムが停止
3. **手動でClaude Codeセッションを起動**
4. **CLAUDE.mdルールに従って1つずつ翻訳**
5. 各編集後に3つの検証を実行
6. 全て合格後にコミット

**結論**:
- ❌ 自動修正は行わない（CLAUDE.mdルール遵守）
- ✅ 検出は確実に動作
- ✅ 手動修正のワークフローが正常に機能
- ✅ バッチ処理を完全に排除

---

## 運用ガイドライン

### 自動化実行時
1. `./automation/auto-retranslate.sh` を実行
2. ログを監視: `tail -f automation/retranslation-automation.log`
3. エラー発生時: `.session_*_output.log` を確認
4. auto-fix失敗時: 手動修正を実施

### 手動修正時
1. 検証スクリプトで問題箇所を特定
2. エントリを手動翻訳
3. 全ての検証を再実行（構造・品質・アクションマーカー）
4. 合格後、git commit & push

### 検証コマンド（手動実行時）
```bash
# 構造検証
python3 translation/validate_structure_v2.py TARGET_FILE \
  --source SOURCE_FILE --detailed

# 品質検証
python3 translation/validate_translation_quality.py TARGET_FILE \
  --reference REFERENCE_FILE \
  --start-line 390 --end-line CURRENT_LINE \
  --glossary translation/nouns_glossary.json

# アクションマーカー検証
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
```

---

## まとめ

**2025-11-09実施の再発防止策**:
1. ✅ 翻訳漏れ**検出**スクリプト作成（検出のみ、自動修正なし）
2. ✅ auto-fix-errors.shに統合（検出時は停止して手動修正を促す）
3. ✅ セッション内検証を強化（品質検証を追加）
4. ✅ コマンドファイルに品質検証を追加
5. ✅ 運用ガイドライン整備
6. ✅ **CLAUDE.mdルールの厳格遵守**（バッチ処理完全排除）

**重要な設計原則**:
- ❌ 自動翻訳は行わない（CLAUDE.mdで禁止）
- ❌ バッチ処理は行わない（CLAUDE.mdで禁止）
- ✅ 検出のみを自動化
- ✅ 修正は必ず手動（CLAUDE.mdルール遵守）
- ✅ シーケンシャル処理の徹底

**期待される結果**:
- 翻訳漏れの早期検出
- CLAUDE.mdルールの完全遵守
- 翻訳品質の向上
- 全作業の追跡可能性確保

**次のアクション**:
- 自動化を再開: `./automation/auto-retranslate.sh`
- 翻訳漏れ検出時: 手動でClaude Codeセッション起動して1つずつ翻訳
- ログを監視してシステムが正常に動作することを確認
- 今後のセッションで再発がないことを検証
