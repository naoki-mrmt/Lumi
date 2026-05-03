# iOS Review Checklist

## TCA
- [ ] Reducer内で直接 async 呼び出しをしていないか (Effect.run 経由か)
- [ ] DependencyKey の testValue が定義されているか
- [ ] State が Equatable に準拠しているか
- [ ] TestStore を使ったテストがあるか

## SwiftUI
- [ ] deprecated API を使っていないか (NavigationView, @ObservedObject等)
- [ ] .task {} でasync処理しているか
- [ ] ForEach の id に安定した値を使っているか
- [ ] アクセシビリティラベルが付いているか (アイコンボタン)

## Concurrency
- [ ] @MainActor が適切に付与されているか
- [ ] Sendable 準拠に問題はないか
- [ ] Task キャンセレーション対応があるか

## SwiftData
- [ ] ModelContext の操作が MainActor 上か
- [ ] データ永続化のフローが正しいか
