# M8: 観測性・クラッシュレポート

## 目的

Sentry とOSLog をフル活用し、本番運用時にクラッシュ・エラー・パフォーマンス問題を検知できる体制を整える。M7 と並行で進める部分もあるが、最終的な観測性の統合をこのマイルストーンで完成させる。

## 完了条件（DoD）

- [ ] Sentry SDK が完全に統合され、クラッシュ自動検知が動作
- [ ] OSLog のカテゴリ設計が完了（sync / input / auth / stats / sync 等）
- [ ] 重要操作のbreadcrumbsがSentryに送信される
- [ ] パフォーマンスモニタリング（特に同期レイテンシ・KPI計算時間）が機能
- [ ] テスト用のクラッシュトリガで Sentry ダッシュボードに到達確認

## 関連ドキュメント

- `docs/02_FEATURE_SPEC.md` — F-1.0.19
- `docs/08_NON_FUNCTIONAL.md` — 4 観測性
- `docs/05_TECH_ARCHITECTURE.md` — Sentry採用理由

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M8-T1 | Sentry SDK 完全統合 | options.dsn / environment / tracesSampleRate 設定 |
| M8-T2 | OSLog カテゴリ設計 | sync / input / auth / stats / pdf / video / ui のカテゴリ |
| M8-T3 | 重要操作のbreadcrumbs | プレー記録・同期・認証・試合切替時に追加 |
| M8-T4 | パフォーマンスモニタリング | 同期push・KPI計算をtransactionとして計測 |
| M8-T5 | クラッシュレポートテスト | デバッグ時にforce crashトリガー、Sentry到達確認 |

## 実装メモ

### Sentry の初期化（M0-T7 で初期化済み・ここで本格化）

```swift
import Sentry

func setupSentry() {
  SentrySDK.start { options in
    options.dsn = AppConfig.sentryDSN
    options.environment = AppConfig.environment  // "development" / "production"
    options.releaseName = "lumi@\(AppConfig.appVersion)"
    options.tracesSampleRate = AppConfig.environment == .production ? 0.1 : 1.0
    options.profilesSampleRate = 0.0  // Phase 1では無効
    options.attachScreenshot = false  // プライバシー考慮
    options.attachViewHierarchy = false
    options.enableAutoBreadcrumbTracking = true
    
    // ユーザー識別（プライバシー考慮）
    options.beforeSend = { event in
      // 個人情報をサニタイズ
      event.user?.email = nil  // メールは送らない
      event.user?.username = nil
      return event
    }
  }
}
```

### OSLogカテゴリ

```swift
import OSLog

extension Logger {
  static let sync   = Logger(subsystem: "com.muramoto-co.lumi", category: "sync")
  static let input  = Logger(subsystem: "com.muramoto-co.lumi", category: "input")
  static let auth   = Logger(subsystem: "com.muramoto-co.lumi", category: "auth")
  static let stats  = Logger(subsystem: "com.muramoto-co.lumi", category: "stats")
  static let pdf    = Logger(subsystem: "com.muramoto-co.lumi", category: "pdf")
  static let video  = Logger(subsystem: "com.muramoto-co.lumi", category: "video")
  static let ui     = Logger(subsystem: "com.muramoto-co.lumi", category: "ui")
}

// 使用例
Logger.sync.info("Pushed play \(playId, privacy: .public) to cloud")
Logger.input.error("Failed to record play: \(error)")
Logger.stats.debug("KPI computed in \(elapsed) ms")
```

### Breadcrumbs の追加

```swift
SentrySDK.addBreadcrumb(
  Breadcrumb(level: .info, category: "match")
    .with { $0.message = "Match started: \(matchId)" }
)

SentrySDK.addBreadcrumb(
  Breadcrumb(level: .info, category: "input")
    .with {
      $0.message = "Play recorded"
      $0.data = ["type": play.playType.rawValue, "evaluation": play.evaluation.rawValue]
    }
)
```

### パフォーマンスtransaction

```swift
// 同期push
let transaction = SentrySDK.startTransaction(name: "sync.push.play", operation: "network")
do {
  try await syncEngine.push(play)
  transaction.finish(status: .ok)
} catch {
  transaction.finish(status: .internalError)
  throw error
}

// KPI計算
let span = transaction.startChild(operation: "stats.compute")
let stats = StatsEngine().teamStats(for: match, scope: .wholeMatch)
span.finish()
```

### クラッシュテスト

```swift
// デバッグメニューに隠しボタン
#if DEBUG
Button("⚠️ Force Crash (Test Sentry)") {
  SentrySDK.crash()
}
#endif
```

ビルドしてシミュレータで実行 → クラッシュ → 再起動 → Sentry ダッシュボードで確認。

### プライバシー考慮事項

- ユーザー氏名・メール・選手名・チーム名 → Sentryには送信しない
- ID（UUID）のみ送信
- `beforeSend` フックで自動サニタイズ

```swift
options.beforeSend = { event in
  // PIIをマスク
  if var contexts = event.context {
    var match = contexts["match"] as? [String: Any] ?? [:]
    match["opponent_team_name"] = "***"  // マスク
    contexts["match"] = match
    event.context = contexts
  }
  return event
}
```

### Free tier の管理

Sentry Free tier は 5,000イベント/月。実戦投入時は：
- `tracesSampleRate = 0.1`（10%サンプリング）
- 重要なエラーのみ手動キャプチャ
- 不要なログは送らない

### M0-T7 との連携

M0-T7 で「テストイベント到達」だけ確認したが、ここで本格的な統合：
- breadcrumbs
- transaction
- カスタムcontext
- beforeSend サニタイズ

## CC に渡すプロンプト雛形

```
M8 を進めてほしい。
docs/progress.json で M7 の進捗を確認。
M0-T7 で初期化済みの Sentry をフル活用する。

特に：
- M8-T1: production と development で tracesSampleRate を分ける
- M8-T2: OSLog はカテゴリ別に整理（後でフィルタしやすく）
- M8-T3: 重要操作（プレー記録・試合切替・認証）にbreadcrumbsを必ず
- プライバシー考慮：選手名・チーム名等のPIIは Sentryに送信しない（beforeSendでマスク）

クラッシュテスト（M8-T5）で Sentry ダッシュボードに到達確認。
各タスク完了ごとに progress.json 更新。
```
