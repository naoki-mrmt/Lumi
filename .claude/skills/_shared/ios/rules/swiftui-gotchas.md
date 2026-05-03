# SwiftUI Gotchas & Best Practices

LLMが間違えやすいポイントに集中。基本は省略。

## Deprecated API (macOS 26+ / iOS 26+)
- `NavigationView` → `NavigationStack` or `NavigationSplitView`
- `@ObservedObject` → `@Observable` + `@Bindable`
- `@StateObject` → `@State` (with @Observable)
- `@EnvironmentObject` → `@Environment`
- `.onChange(of:perform:)` → `.onChange(of:) { oldValue, newValue in }`
- `List { ForEach }` での `.onDelete` → `.swipeActions` 推奨

## パフォーマンス
- `@Observable` は変更されたプロパティのみView更新。`@ObservableObject` より高効率
- `List` 内の重い計算は `EquatableView` or メモ化
- `Image` は `resizable()` を先に、`aspectRatio` は後
- `GeometryReader` は最小スコープに留める (Viewの最上位に置かない)

## アクセシビリティ
- `Button` に `.accessibilityLabel` を必ず付ける (アイコンのみの場合)
- `.accessibilityHidden(true)` で装飾要素を隠す
- Dynamic Type: 固定フォントサイズを避け `.font(.body)` 等を使う

## よくあるミス
- `.task {}` は View が表示されるたびに呼ばれる、not once
- `.sheet(isPresented:)` で渡す Binding が意図せず変わるとシートが閉じる
- `@State` は View の struct 内でのみ初期化、init で代入しない
- `ForEach` の `id:` に配列インデックスを使わない (安定したidを使う)
