# SwiftData Gotchas

## 基本
- `@Model` class は MainActor 上で操作
- ModelContainer は App 起動時に1回だけ生成
- `modelContext.save()` は明示的に呼ぶ (自動保存に頼らない)

## Calame での使い方
- SwiftData が唯一のデータ永続化手段（UserDefaults, CoreData は不使用）
- 管理対象: 入力ログ・履歴、カスタム辞書、アプリ別プロファイル、ユーザー設定

## よくあるミス
- `@Query` は View 内でのみ使用、ViewModel (Reducer) 内では ModelContext を直接使う
- Relationship で cascade delete の挙動に注意
- Background context を使う場合は別スレッドで ModelContext を生成
