# ios-impl Instructions

## 事前読み込み
1. 仕様書を読む (docs/specs/*.md)
2. 共有ルールを読む:
   - `.claude/skills/_shared/ios/rules/tca-patterns.md`
   - `.claude/skills/_shared/ios/rules/swiftui-gotchas.md`
   - `.claude/skills/_shared/ios/rules/swiftdata-gotchas.md`
   - `.claude/skills/_shared/ios/rules/concurrency-gotchas.md`
   - `.claude/skills/_shared/design/hig-ios.md`
3. 既存コードの構造を確認:
   - `Packages/CalameKit/Sources/` のモジュール構成
   - 関連する既存の Feature / Domain コード

## 実装フロー (TDD)

### 1. Domain 層 (必要な場合)
```
Packages/CalameKit/Sources/Domain/
```
- Protocol を先に定義
- 実装はプロトコルに準拠
- テスト: `Packages/CalameKit/Tests/DomainTests/`

### 2. Persistence 層 (必要な場合)
```
Packages/CalameKit/Sources/Persistence/
```
- SwiftData `@Model` 定義
- Repository プロトコル + 実装
- テスト: `Packages/CalameKit/Tests/PersistenceTests/`

### 3. Feature 層
```
Packages/CalameKit/Sources/Features/{FeatureName}/
```
- `{FeatureName}Feature.swift` — Reducer (State, Action, body)
- `{FeatureName}View.swift` — SwiftUI View
- DependencyKey で Domain 層を注入
- テスト: `Packages/CalameKit/Tests/FeatureTests/`

### 4. SharedUI (必要な場合)
```
Packages/CalameKit/Sources/SharedUI/
```
- 再利用可能な UI コンポーネント

## TDD サイクル

各ステップで:
1. **Red**: テストを書く → `cd Packages/CalameKit && swift test` → 失敗確認
2. **Green**: 最小実装 → テスト通過
3. **Refactor**: コード改善 → テスト維持

## ビルド・テストコマンド

```bash
# SPM テスト (高速、主要開発ループ)
cd Packages/CalameKit && swift test

# 特定テストのみ
cd Packages/CalameKit && swift test --filter {TestName}

# フルビルド
xcodebuild -project Calame.xcodeproj -scheme Calame-macOS -destination 'platform=macOS' build

# フルテスト
xcodebuild -project Calame.xcodeproj -scheme Calame-macOS -destination 'platform=macOS' test
```

## チェックリスト (完了前)
- [ ] テストが全て通る
- [ ] 仕様書の要件をすべて満たしている
- [ ] TCA パターンに準拠 (Effect.run, DependencyKey)
- [ ] SwiftUI deprecated API を使っていない
- [ ] Concurrency (Sendable, @MainActor) が適切
- [ ] アクセシビリティ対応
- [ ] Preview が動作する
