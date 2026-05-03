# review Instructions

## 事前読み込み

1. レビューチェックリストを読む:
   - `.claude/skills/_shared/ios/review-checklist.md`
2. 共有ルールを読む:
   - `.claude/skills/_shared/ios/rules/tca-patterns.md`
   - `.claude/skills/_shared/ios/rules/swiftui-gotchas.md`
   - `.claude/skills/_shared/ios/rules/swiftdata-gotchas.md`
   - `.claude/skills/_shared/ios/rules/concurrency-gotchas.md`
3. HIG を確認:
   - `.claude/skills/_shared/design/hig-ios.md`

## レビュー対象の特定

### git diff ベースの場合
```bash
git diff --name-only HEAD~1
git diff HEAD~1
```

### ファイルパス指定の場合
- 指定されたファイルを読む
- 関連するテストファイルも確認

## レビュー観点

### 1. TCA パターン
- Reducer 内で直接 async 呼び出しをしていないか (Effect.run 経由か)
- DependencyKey の testValue が定義されているか
- State が Equatable に準拠しているか
- TestStore を使ったテストがあるか
- Action の命名が適切か (user/internal/delegate)
- Navigation パターンが TCA の推奨に沿っているか

### 2. SwiftUI
- deprecated API を使っていないか
- .task {} で async 処理しているか
- ForEach の id に安定した値を使っているか
- アクセシビリティラベルが付いているか
- パフォーマンス (不要な再描画がないか)

### 3. Swift Concurrency
- @MainActor が適切に付与されているか
- Sendable 準拠に問題はないか
- Task キャンセレーション対応があるか
- Actor isolation の境界が正しいか

### 4. SwiftData
- ModelContext の操作が MainActor 上か
- データ永続化のフローが正しいか
- Relationship の cascade 設定が適切か

### 5. モジュール設計
- Core / Domain / Persistence / Features の境界が正しいか
- 逆方向の依存がないか (Features → Domain は OK、Domain → Features は NG)
- プロトコルで抽象化されているか

### 6. テスト
- テストがあるか
- TestStore の exhaustivity が守られているか
- 依存が適切にモック化されているか
- Edge case がカバーされているか

## 出力フォーマット

```markdown
## レビュー結果: {ファイル名 or PR}

### 🔴 Must Fix
1. **{ファイル}:{行}** — {問題の説明}
   ```swift
   // 問題のあるコード
   ```
   **修正案:**
   ```swift
   // 修正後のコード
   ```

### 🟡 Should Fix
1. ...

### 🟢 Nit
1. ...

### ✅ Good Points
- {良かった点}
```

## チェックリスト (レビュー完了前)
- [ ] TCA パターンを確認した
- [ ] SwiftUI deprecated API を確認した
- [ ] Concurrency の安全性を確認した
- [ ] SwiftData の使い方を確認した
- [ ] テストの存在と品質を確認した
- [ ] モジュール境界を確認した
