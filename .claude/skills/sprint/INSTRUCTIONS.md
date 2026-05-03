# sprint Instructions

## 事前読み込み

1. ロードマップを確認:
   - `docs/ROADMAP.md` — 全体計画とフェーズ
   - `docs/tasks/phase{N}.md` — 現在フェーズの詳細タスク
2. 設計ドキュメントを確認:
   - `docs/DESIGN.md` — アーキテクチャ方針
3. 現在の状態を確認:
   ```bash
   git log --oneline -10
   git status
   ```

## タスク依存関係

CalameKit のモジュール依存に基づいてタスク実行順を決定:

```
Core (Foundation層)
  ↓
Domain (ビジネスロジック Protocol + 実装)
  ↓
Persistence (SwiftData モデル + Repository)
  ↓
Features (TCA Reducer + SwiftUI View)
  ↓
App targets (macOS / iOS / KeyboardExtension)
```

**ルール:**
- 下位モジュールのタスクを先に完了
- 同一レイヤーのタスクは並行可能
- Feature は依存する Domain が完成してから着手

## スプリント実行フロー

### 1. タスク選定
- `docs/tasks/phase{N}.md` から未完了タスクを抽出
- 依存関係に基づいて実行順を決定
- 1タスクのスコープを確認 (大きすぎる場合は分割)

### 2. タスクごとのサイクル

各タスクで以下のサブスキルを順に実行:

#### a. `/spec` — 仕様策定
- タスクの仕様書を作成
- State / Action / DependencyKey の設計

#### b. `/ios-impl` — 実装
- TDD で実装
- Domain → Persistence → Feature の順

#### c. `/review` — レビュー
- 実装のセルフレビュー
- チェックリストの確認

#### d. `/ship` — コミット
- 変更をコミット
- 必要に応じて PR 作成

### 3. タスク完了の記録
- `docs/tasks/phase{N}.md` のチェックボックスを更新
- 必要に応じて ROADMAP.md を更新

## スプリントの終了条件

- フェーズ内の全タスクが完了
- すべてのテストが pass
- コードレビュー完了

## 出力フォーマット

```markdown
## Sprint 結果: Phase {N}

### 完了タスク
- [x] {タスク1} — {コミットハッシュ}
- [x] {タスク2} — {コミットハッシュ}

### 未完了
- [ ] {タスク3} — {理由}

### テスト結果
- SPM テスト: {pass}/{total}
- ビルド: macOS ✅ / iOS ✅

### 次のスプリントへの申し送り
- {申し送り事項}
```

## 注意事項
- 1タスクが大きすぎる場合は分割を提案
- ブロッカーが発生した場合は `/investigate` で調査
- 定期的に `/verify` でビルド・テストを確認
