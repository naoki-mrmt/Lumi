# Spec: {Feature Name}

## 概要
{機能の概要・目的}

## 背景
- ROADMAP: Phase {N} — {関連タスク}
- 関連: {既存の Feature / Domain}

## 対象プラットフォーム
- [ ] macOS
- [ ] iOS
- [ ] Keyboard Extension

## ユーザーストーリー
1. ユーザーが {操作} すると {結果} になる

## 設計

### モジュール配置
```
Packages/CalameKit/Sources/
├── Domain/{FeatureName}Protocol.swift      # (必要な場合)
├── Persistence/{ModelName}.swift           # (必要な場合)
└── Features/{FeatureName}/
    ├── {FeatureName}Feature.swift
    └── {FeatureName}View.swift
```

### State
```swift
@ObservableState
struct State: Equatable {
    // TODO: 状態を定義
}
```

### Action
```swift
enum Action {
    // User actions
    // Internal actions (delegate, response)
}
```

### Effect / 副作用
| Action | Effect | 説明 |
|--------|--------|------|
| | | |

### DependencyKey
```swift
struct {Name}Client {
    var method: @Sendable (Param) async throws -> Result
}
```

### SwiftData Model (必要な場合)
```swift
@Model
final class {ModelName} {
    // TODO: プロパティ定義
}
```

### Domain Protocol (必要な場合)
```swift
protocol {Name}Protocol: Sendable {
    func method() async throws -> Result
}
```

## UI 設計

### macOS
{画面構成の説明}

### iOS
{画面構成の説明}

## テスト戦略

### TestStore テスト
1. {テストケース1}: {操作} → {期待する状態変化}
2. {テストケース2}: {操作} → {期待する状態変化}

### モック化する依存
- `{Client}Client`: {モック内容}

### Edge Case
- {ケース1}

## 非機能要件
- [ ] アクセシビリティ
- [ ] パフォーマンス (目標値があれば記載)
- [ ] エラーハンドリング

## 未決定事項
- {決まっていない点}
