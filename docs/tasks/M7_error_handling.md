# M7: エラーハンドリング・障害時UX

## 目的

試合中にアプリが「絶対に止まらない」ようにする。Phase 1.0 の要件として10種類のエラーパターンすべてに対応する独立マイルストーン。M0〜M6と並行して進める部分もあるが、最終的な統合とテストはこのマイルストーンで完成させる。

## 完了条件（DoD）

- [ ] AppError が型として整備され、グローバルエラーハンドリング設計が機能
- [ ] 10パターン全てのエラーケースに対応UIが実装済み
- [ ] エラーシナリオの統合テストが緑（オフライン・クラッシュ・コード誤入力等）
- [ ] 重大度別のエラー表現UI（軽微/中/重大/致命的）が機能
- [ ] スキーマ自動マイグレーション機構が動作

## 関連ドキュメント

- `docs/02_FEATURE_SPEC.md` — F-1.0.18
- `docs/08_NON_FUNCTIONAL.md` — 3 エラーハンドリング・障害時UX
- `docs/06_DATA_SYNC.md` — 同期失敗時の動作
- `docs/07_AUTH.md` — 認証エラー時のフォールバック

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M7-T1 | AppError 設計・グローバルエラーハンドリング | enum・severity・userMessage・TCA上位伝播 |
| M7-T2 | ネット切断時のオフライン継続UX | バナー警告・操作続行可能 |
| M7-T3 | Supabase書き込み失敗時の再送 | 指数バックオフ統合（M4と接続） |
| M7-T4 | 試合コード誤入力時のメッセージング | リアルタイム検証・理由明示 |
| M7-T5 | Recorderクラッシュリカバリ | 起動時に「中断中の試合を復元しますか？」 |
| M7-T6 | バッテリー低下警告 | 残量20%以下でバナー、UIDevice.current.batteryLevel監視 |
| M7-T7 | Sign in with Apple失敗時のフォールバック | エラーメッセージ + メール認証への導線（Phase 2準備） |
| M7-T8 | 同一試合への2人目Recorder検知 | 後者を強制Viewer・メッセージ表示（M4と接続） |
| M7-T9 | データ整合性バリデーション | 試合・セット・選手交代等のドメイン制約 |
| M7-T10 | スキーマ自動マイグレーション | アプリアップデート時にSwiftDataマイグレーション・失敗時にバックアップ |
| M7-T11 | 重大度別のエラー表現UI | バナー / トースト / モーダル / 起動時ダイアログ の4階層 |

## 実装メモ

### AppError の型設計

```swift
public enum AppError: Error, Equatable, Identifiable {
  case network(NetworkError)
  case auth(AuthError)
  case sync(SyncError)
  case validation(ValidationError)
  case dataInconsistency(reason: String)
  case migration(MigrationError)
  case unknown(message: String)
  
  public var id: String {
    switch self {
    case .network(let e): return "network.\(e)"
    // ...
    }
  }
  
  public var userMessage: LocalizedStringKey {
    switch self {
    case .network(.disconnected):
      return "ネットワークから切断されました。オフラインモードで継続します。"
    case .sync(.bufferFull):
      return "未同期のデータが多数あります。ネット環境のよい場所に移動してください。"
    case .auth(.signInWithAppleFailed):
      return "Apple ID でのログインに失敗しました。"
    // ...
    }
  }
  
  public var severity: Severity {
    switch self {
    case .network(.disconnected): return .minor      // バナー
    case .sync(.bufferFull):       return .moderate   // トースト
    case .auth(.signInFailed):     return .severe     // モーダル
    case .dataInconsistency:       return .critical   // 起動時ダイアログ
    // ...
    }
  }
}

public enum Severity {
  case minor      // 軽微：上部バナー、5秒で自動消滅
  case moderate   // 中：トースト通知、操作続行可能
  case severe     // 重大：モーダルダイアログ、復旧手段提示
  case critical   // 致命的：起動時ダイアログ
}
```

### TCAでのエラー伝播

```swift
@Reducer
public struct AppFeature {
  @ObservableState
  public struct State: Equatable {
    var error: AppError?
    var route: Route = .home
    // ...
  }
  
  public enum Action {
    case errorReceived(AppError)
    case errorDismissed
    // ...
  }
  
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .errorReceived(let error):
        state.error = error
        // Sentryにキャプチャ
        SentrySDK.capture(error: error)
        return .none
      
      case .errorDismissed:
        state.error = nil
        return .none
      // ...
      }
    }
  }
}
```

各 Feature の Effect 内：

```swift
return .run { send in
  do {
    try await syncEngine.push(play)
  } catch let error as SyncError {
    await send(.errorReceived(.sync(error)))
  } catch {
    await send(.errorReceived(.unknown(message: error.localizedDescription)))
  }
}
```

### ネット切断時のUI

```swift
struct OfflineBanner: View {
  let pendingCount: Int
  
  var body: some View {
    HStack {
      Image(systemName: "wifi.slash")
      VStack(alignment: .leading) {
        Text("オフライン")
        Text("未同期: \(pendingCount)件")
          .font(.caption)
      }
    }
    .padding(8)
    .background(.orange.opacity(0.2))
    .foregroundStyle(.orange)
  }
}
```

### 試合コード誤入力時

```swift
@Reducer
public struct MatchCodeEntryFeature {
  @ObservableState
  public struct State: Equatable {
    var code: String = ""
    var validationState: ValidationState = .idle
    
    public enum ValidationState: Equatable {
      case idle
      case validating
      case invalid(reason: String)  // "コードが見つかりません" / "期限切れ" 等
      case valid(matchId: UUID)
    }
  }
  
  // 入力ごとにリアルタイム検証
}
```

### バッテリー監視

```swift
@MainActor
@Observable
public class BatteryMonitor {
  private(set) var level: Float = 1.0
  private(set) var isLowBattery: Bool = false
  
  init() {
    UIDevice.current.isBatteryMonitoringEnabled = true
    
    NotificationCenter.default.addObserver(
      forName: UIDevice.batteryLevelDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      Task { @MainActor in
        self.level = UIDevice.current.batteryLevel
        self.isLowBattery = self.level <= 0.2 && self.level > 0
      }
    }
  }
}
```

### スキーマ自動マイグレーション

SwiftData の VersionedSchema を使用：

```swift
enum DataSchemaV1: VersionedSchema {
  static var versionIdentifier = Schema.Version(1, 0, 0)
  static var models: [any PersistentModel.Type] { [Match.self, /* ... */] }
}

enum DataSchemaV2: VersionedSchema {
  static var versionIdentifier = Schema.Version(2, 0, 0)
  static var models: [any PersistentModel.Type] { [Match.self, /* 新フィールド */] }
}

enum MigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [DataSchemaV1.self, DataSchemaV2.self]
  }
  
  static var stages: [MigrationStage] {
    [migrateV1ToV2]
  }
  
  static let migrateV1ToV2 = MigrationStage.lightweight(
    fromVersion: DataSchemaV1.self,
    toVersion: DataSchemaV2.self
  )
}
```

マイグレーション失敗時 → バックアップから復元のフォールバック。

### 統合テスト（重要）

```swift
@Test
func offlineThenReconnect() async {
  // 1. オフラインに切替
  await NetworkMonitorMock.simulate(offline: true)
  
  // 2. プレー入力
  await store.send(.playRecorded(play))
  
  // 3. ローカルバッファに保留されることを確認
  let pending = try await localStore.fetchPendingPlays()
  #expect(pending.count == 1)
  
  // 4. オンラインに復帰
  await NetworkMonitorMock.simulate(offline: false)
  
  // 5. 自動再送される
  try await Task.sleep(for: .seconds(2))
  let pendingAfter = try await localStore.fetchPendingPlays()
  #expect(pendingAfter.isEmpty)
}
```

### M7のM4・M5・M6との連携

M7は独立マイルストーンだが、各機能の実装段階で並行して仕組みを組み込む：
- M4実装時：M7-T2, T3, T8 を一緒に実装
- M5実装時：M7-T11（重大度別UI）の素地を作る
- M0-M6 完了後にM7全体を統合・テスト

## CC に渡すプロンプト雛形

```
M7 を進めてほしい。
これは「絶対に試合中に止まらない」ためのマイルストーン。

docs/progress.json で M0〜M6 の状況を確認。M4・M5実装時に並行で
組み込んだエラーハンドリングがあれば、それと統合してほしい。

特に：
- M7-T1: AppError は型として厳密に・severityで階層化
- M7-T5: クラッシュリカバリは絶対動くこと（試合データロスは致命）
- M7-T9: データ整合性バリデーションは厳しく（不整合データの保存は防ぐ）
- M7-T10: SwiftData VersionedSchema を使用、失敗時はバックアップ復元

統合テスト（特にオフラインシナリオ・クラッシュ復帰）は厚く書いてほしい。

各タスク完了ごとに progress.json 更新。
```
