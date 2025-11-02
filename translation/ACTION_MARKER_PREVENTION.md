# アクションマーカー翻訳エラー再発防止策

## 問題の概要

**発生日**: 2025-11-02
**Session**: #7
**エラー内容**: 3つのアクションマーカーが誤って日本語に翻訳された

### 発生したエラー

| 行番号 | 誤訳 (NG) | 正解 (OK) |
|--------|-----------|-----------|
| 232532 | `::静かに鼻歌を歌う::` | `::hums quietly::` |
| 232596 | `::電気的な鼾::` | `::electric snores::` |
| 233980 | `::ため息をつく::` | `::sighs::` |

### 影響範囲

- ゲームエンジンがアクションマーカーを認識できなくなる
- キャラクターアニメーション・効果音が再生されない
- プレイヤー体験が損なわれる

## 根本原因分析

### 1. プロンプトの問題

**現状**: automation scriptのプロンプトで `::action::` 保護は記載されているが、具体例が不足

```
現在のプロンプト (行418):
   - []、<>、::action:: 保護
```

**問題点**:
- ❌ 具体的な悪い例・良い例がない
- ❌ 「翻訳してはいけない」という明確な警告がない
- ❌ アクションマーカーが何かの説明がない

### 2. 検証タイミングの問題

**現状**: 検証は1回のみ（コミット前）

```
現在のワークフロー:
1. 翻訳実行
2. コミット前に validate_structure_v2.py 実行
3. コミット前に validate_translation_quality.py 実行
```

**問題点**:
- ❌ 編集直後の検証がない（エラー発見が遅い）
- ❌ 複数エントリをまとめて編集した場合、どのエントリでエラーが発生したか特定しにくい

### 3. 検証スクリプトの実行パラメータ問題

**判明した事実**:
- automation scriptは `--reference` パラメータを正しく渡している
- しかし、validation失敗時に6つの「untranslated English entries」として誤検出された
- これは、Spanish empty entries を「翻訳すべき」と判定するロジックの問題の可能性

## 再発防止策

### 対策1: プロンプト強化 (PRIORITY: HIGH)

**実装内容**: automation scriptのプロンプトにアクションマーカーの具体的な警告を追加

```bash
# auto-retranslate.sh の CAT <<'EOF' セクションに追加

⚠️⚠️⚠️ **CRITICAL: アクションマーカー保護 (絶対厳守)** ⚠️⚠️⚠️

**アクションマーカーとは**:
ゲームエンジン制御コマンド。形式: ::action::
例: ::sigh::, ::laughs::, ::nods::, ::static::, ::gunfire::

**絶対ルール (ZERO TOLERANCE)**:
❌ **絶対禁止**: アクションマーカー内容を日本語に翻訳
❌ **絶対禁止**: アクションマーカーを削除・変更

✅ **正しい処理**: 英語のまま、文字単位で完全一致保持

**悪い例 (NG - ゲームが壊れる)**:
英語: string data = "::sigh:: "I don't know...""
日本語: string data = "::ため息:: "わからない..."" ❌ WRONG!

**正しい例 (OK)**:
英語: string data = "::sigh:: "I don't know...""
日本語: string data = "::sigh:: "わからない..."" ✅ CORRECT!

**検証方法**:
編集後、必ず以下を実行してアクションマーカーに日本語が含まれていないことを確認:
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
→ 結果が空であること (何も表示されないこと)
EOF
```

**効果**:
- 具体例により、Claude Codeがアクションマーカーの重要性を理解
- 「ZERO TOLERANCE」という強い表現で警告レベルを最高に設定
- 検証コマンドにより、自己チェックが可能

### 対策2: 二段階検証の導入 (PRIORITY: HIGH)

**実装内容**: 編集直後の自動検証機能をプロンプトに追加

```bash
# プロンプトに追加

**各編集後の即時検証 (MANDATORY)**:

編集ツール実行後、必ず以下を実行:

1. **構造検証**:
   python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_FILE --detailed

2. **アクションマーカー検証**:
   grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE

   → 結果が空でない場合 = アクションマーカーに日本語が含まれている = 即座に修正

3. **エラーがある場合**:
   - 次の編集に進まず、即座に修正
   - 修正後、再度検証
   - 全エラー解消まで繰り返す

このルールにより、エラーの早期発見・早期修正が可能になります。
```

**効果**:
- エラー発見が早期化（編集直後）
- エラー箇所の特定が容易（最後に編集したエントリが原因）
- 蓄積エラーの防止

### 対策3: Git pre-commitフックの導入 (PRIORITY: MEDIUM)

**実装内容**: コミット前に自動検証を実行するGit hookを作成

```bash
# .git/hooks/pre-commit

#!/bin/bash

TARGET_FILE="translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"

# アクションマーカーに日本語が含まれていないかチェック
JAPANESE_IN_ACTIONS=$(grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' "$TARGET_FILE" 2>/dev/null)

if [ -n "$JAPANESE_IN_ACTIONS" ]; then
    echo "❌ ERROR: Action markers contain Japanese characters!"
    echo "Found:"
    echo "$JAPANESE_IN_ACTIONS"
    echo ""
    echo "Action markers MUST remain in English. Please fix before committing."
    exit 1
fi

echo "✅ Action marker validation passed"
exit 0
```

**効果**:
- コミット前の最終チェック（safety net）
- 自動化により人的ミスを防止
- CI/CDパイプラインに統合可能

### 対策4: Quality Validation Scriptの改善 (PRIORITY: MEDIUM)

**問題**: 現在のscriptは、Spanish empty entriesを「untranslated」として誤検出する可能性

**実装内容**: validation scriptのロジックを見直し

```python
# validate_translation_quality.py (line 156-166)

# 現在のロジック
if line_num in spanish_data:
    spanish_content = spanish_data[line_num]

    # If Spanish is empty, this is a program identifier → Keep English (NOT an error)
    if not spanish_content.strip():
        return issues  # ← ここで正しくreturnしているはず

# 改善: より明確なログ出力
if line_num in spanish_data:
    spanish_content = spanish_data[line_num]

    if not spanish_content.strip():
        # DEBUG logging (optional)
        # print(f"DEBUG: Line {line_num} - Spanish empty, keeping English")
        return issues
```

**追加チェック**: Spanish referenceパラメータが必須であることを確認

```python
# validate_translation_quality.py の main() に追加

if not args.reference:
    print("WARNING: No Spanish reference provided.")
    print("This may lead to false positives for untranslated entries.")
    print("Recommended: Use --reference SPANISH_FILE for accurate validation")
```

**効果**:
- 誤検出の削減
- デバッグ情報の充実
- ユーザーへの明確な警告

### 対策5: CLAUDE.mdの更新 (PRIORITY: HIGH)

**実装内容**: プロジェクトルートのCLAUDE.mdに、アクションマーカー保護を強調

```markdown
## 5. **::action:: Markers - ABSOLUTELY CRITICAL** ⚠️🔴

**2025-11-02 UPDATE: 再発防止策実施済み**

Session 7で3件のアクションマーカー翻訳エラーが発生し、修正しました。
今後、以下のルールを絶対厳守してください。

**ABSOLUTE RULES (ZERO TOLERANCE)**:

❌ **NEVER translate action marker content**:
... (既存の内容)

⚠️⚠️⚠️ **編集後の検証 (MANDATORY)**: ⚠️⚠️⚠️
各編集完了後、必ず以下のコマンドを実行:
\`\`\`bash
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
\`\`\`
→ 結果が空であること (何も表示されない = OK)
→ 何か表示される = アクションマーカーに日本語が含まれている = 即座に修正
```

**効果**:
- プロジェクト参加者全員への明確な警告
- 手動セッションでのエラー防止
- 過去のエラー事例の記録

## 実装優先度

| 対策 | 優先度 | 実装難易度 | 効果 | 実装時期 |
|------|--------|------------|------|----------|
| 対策1: プロンプト強化 | **HIGH** | 低 | 大 | 即時 |
| 対策2: 二段階検証 | **HIGH** | 低 | 大 | 即時 |
| 対策3: pre-commitフック | MEDIUM | 中 | 中 | 1週間以内 |
| 対策4: Validation改善 | MEDIUM | 中 | 中 | 1週間以内 |
| 対策5: CLAUDE.md更新 | **HIGH** | 低 | 大 | 即時 |

## 実装ロードマップ

### Phase 1: 即時実装 (今日中)

1. ✅ **対策5**: CLAUDE.mdに警告追加（既に実施済み）
2. ⏳ **対策1**: automation scriptプロンプト強化
3. ⏳ **対策2**: 二段階検証をプロンプトに追加

### Phase 2: 短期実装 (1週間以内)

4. ⏳ **対策3**: pre-commitフック作成
5. ⏳ **対策4**: validation scriptログ改善

## 期待効果

### 定量的効果

- **エラー発生率**: 3/16,375 (0.018%) → 目標 0%
- **エラー検出時間**: コミット前（約5分遅延） → 編集直後（即時）
- **修正コスト**: Session全体やり直し → 個別エントリ修正のみ

### 定性的効果

- 翻訳品質の向上
- 自動化スクリプトの信頼性向上
- メンテナンスコストの削減
- プロジェクト参加者への明確なガイドライン提供

## モニタリング計画

### 短期モニタリング (次10セッション)

- アクションマーカーエラーの発生件数
- 二段階検証の実行状況
- pre-commitフックの動作確認

### 長期モニタリング (次100セッション)

- 全体的なエラー傾向
- 再発防止策の有効性評価
- 改善提案の収集

---

**作成日**: 2025-11-02
**最終更新**: 2025-11-02
**責任者**: Claude Code Automation
**レビュー**: 必要に応じて更新
