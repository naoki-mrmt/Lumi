# TCA Patterns & Testing

## DependencyKey パターン
```swift
struct SomeClient {
    var doSomething: @Sendable () async throws -> Result
}

extension SomeClient: DependencyKey {
    static let liveValue = SomeClient(
        doSomething: { /* real implementation */ }
    )
    static let testValue = SomeClient(
        doSomething: unimplemented("SomeClient.doSomething")
    )
}

extension DependencyValues {
    var someClient: SomeClient {
        get { self[SomeClient.self] }
        set { self[SomeClient.self] = newValue }
    }
}
```

## テストでの Effect 検証
- `store.send` で Action を送り state 変化を検証
- `store.receive` で Effect から返る Action を検証
- `withDependencies` で外部依存をモック化
- exhaustivity: すべての state 変化と Action を検証

## Navigation (TCA)
- `@Presents` + `.ifLet` for optional destinations
- `StackState` + `StackAction` for NavigationStack
- path ベースのナビゲーション推奨

## 共通ミス
- Reducer内で直接 async 関数を呼ばない → Effect.run で包む
- State の Equatable 準拠を忘れない
- Action に Equatable は不要 (TCA 1.x)
- TestStore で receive を忘れると exhaustivity エラー
