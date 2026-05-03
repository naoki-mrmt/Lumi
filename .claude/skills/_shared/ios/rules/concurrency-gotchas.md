# Swift Concurrency Gotchas

## Actor Isolation
- `@MainActor` を View, Reducer, UI操作する Service に付与
- non-Sendable 型を actor 境界で渡さない
- `nonisolated` を明示的に使って意図を示す

## Task キャンセレーション
- `Task.isCancelled` を長い処理のループ内でチェック
- `withTaskCancellationHandler` でクリーンアップ
- `.task {}` modifier は View 消失時に自動キャンセル

## AsyncStream
- `AsyncStream.makeStream()` で (stream, continuation) ペアを作る
- `continuation.finish()` を忘れるとリーク
- `for await` ループは stream が finish するまでブロック

## よくあるミス
- `Task { }` のキャプチャリストで `[weak self]` が不要な場合が多い (struct の場合)
- `async let` は宣言スコープを抜けるとキャンセルされる
- `MainActor.run {}` より `@MainActor` 関数の方が安全
