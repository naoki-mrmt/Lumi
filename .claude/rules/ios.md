# iOS開発ルール

## 技術スタック
- SwiftUI + TCA (Composable Architecture) 1.25.x
- SPMマルチモジュール構成 (LumiKit) ※構成後
- Swift 6.x strict concurrency (async/await, Actor)
- SwiftData (唯一の永続化手段)
- iOS 26+ / iPadOS 26+ (iPad横画面専用)

## SPMモジュール構成 (予定: Packages/LumiKit/)
```
Sources/
  Core/         — Models/, Extensions/, Constants
  Domain/       — StatsEngine/, ServiceOrderEngine/, RallyTimeline/, Validators/
  Persistence/  — SwiftDataModels/, Repository/, Migration/
  Features/     — MatchSetup/, MatchInput/, MatchViewer/, Review/, TeamManagement/, Auth/
  SharedUI/     — Components/, DesignTokens/
  Infrastructure/ — SupabaseClient/, Sync/, PDFGenerator/, VideoSync/
Tests/
  DomainTests/, PersistenceTests/, FeatureTests/
```

## TCA規約
- Feature = `@Reducer` + View のペア
- `@ObservableState` for State
- `@Dependency` で外部依存を注入
- テストでは TestStore + override で検証
- Effect内のエラーは Action で伝播、View側で表示
- Domain層はTCA非依存 — Protocol で抽象化

## SwiftUI gotchas
- `NavigationStack` 使用 (`NavigationView` 非推奨)
- `@Observable` 使用 (`@ObservedObject` 不使用)
- List内のForEachには安定したidを使う
- `.task {}` でasync処理、`onAppear` でasyncは使わない
- Preview用モックデータを必ず用意

## SwiftData gotchas
- `@Model` classは MainActor 上で操作
- SwiftDataが唯一のデータ永続化手段（UserDefaults, CoreData 不使用）
- ModelContainer は App 起動時に1回だけ生成

## Concurrency gotchas
- `@MainActor` を View と Reducer に付与
- `Sendable` 準拠を意識、non-Sendable型をactor境界で渡さない
- TaskGroup で並列処理する際はキャンセレーション対応必須
