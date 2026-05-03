# 05. Tech Architecture — 技術アーキテクチャと選定

## 1. 技術スタック サマリ

| レイヤ | 採用 | 代替案 |
|---|---|---|
| 言語 | Swift 6.0+ | - |
| UI | SwiftUI | - |
| アーキテクチャ | TCA (The Composable Architecture) | - |
| パッケージ管理 | Swift Package Manager（SPM） | CocoaPods |
| ローカル保存 | SwiftData | Core Data |
| クラウド | Supabase | Firebase |
| 認証 | Sign in with Apple + Supabase Auth | - |
| 観測性 | Sentry | Firebase Crashlytics |
| テスト | Swift Testing + TCA TestStore + swift-snapshot-testing | XCTest |
| CI | GitHub Actions | Xcode Cloud |
| 最低OS | iOS 26+ / iPadOS 26+ | - |

## 2. アーキテクチャ概観

### 2.1 レイヤー構成

```
┌──────────────────────────────────────────────────┐
│   App (Entry Point)                              │
│   - Recorder iPad app target                     │
│   - Viewer iPad app target (※将来 統合検討)        │
└──────────────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────┐
│   Feature Modules (TCA Reducers + Views)         │
│   - MatchSetupFeature                            │
│   - MatchInputFeature                            │
│   - MatchViewerFeature                           │
│   - ReviewFeature                                │
│   - TeamManagementFeature                        │
│   - AuthFeature                                  │
└──────────────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────┐
│   Domain Modules (Pure Swift)                    │
│   - Models（エンティティ定義）                       │
│   - StatsEngine（KPI計算ロジック）                  │
│   - ServiceOrderEngine（サービス順管理）            │
│   - RallyTimeline（ラリー時系列管理）               │
└──────────────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────┐
│   Infrastructure Modules                         │
│   - LocalStore (SwiftData)                       │
│   - SupabaseClient                               │
│   - Sync (Recorder/Viewer 同期ロジック)           │
│   - PDFGenerator                                 │
│   - VideoSync                                    │
└──────────────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────┐
│   Core / DesignSystem                            │
│   - DesignTokens（色・フォント等）                  │
│   - SharedComponents（汎用UIコンポーネント）         │
│   - Logger / Telemetry                           │
└──────────────────────────────────────────────────┘
```

### 2.2 SPMマルチモジュール構成

`Package.swift` で以下のモジュールを定義：

```
lumi/
├── App/                              ← Xcode app target
│   ├── Lumi.swift          ← @main
│   └── ...
├── Sources/
│   ├── AppFeature/                   ← ルートTCA Reducer
│   ├── MatchSetupFeature/
│   ├── MatchInputFeature/
│   ├── MatchViewerFeature/
│   ├── ReviewFeature/
│   ├── TeamManagementFeature/
│   ├── AuthFeature/
│   ├── Models/                       ← ドメインエンティティ
│   ├── StatsEngine/                  ← KPI計算
│   ├── ServiceOrderEngine/           ← サービス順管理
│   ├── RallyTimeline/                ← ラリー時系列管理
│   ├── LocalStore/                   ← SwiftData wrapper
│   ├── SupabaseClient/               ← Supabase wrapper
│   ├── Sync/                         ← 同期ロジック
│   ├── PDFGenerator/                 ← PDF出力
│   ├── VideoSync/                    ← 動画同期
│   ├── DesignSystem/                 ← デザイントークン・共通UI
│   └── Telemetry/                    ← Sentry/OSLog wrapper
├── Tests/
│   ├── ModelsTests/
│   ├── StatsEngineTests/
│   ├── ServiceOrderEngineTests/
│   ├── RallyTimelineTests/
│   ├── MatchInputFeatureTests/       ← TCA TestStore
│   ├── MatchSetupFeatureTests/
│   ├── PDFGeneratorTests/
│   ├── SnapshotTests/                ← UIスナップショット
│   └── ...
├── Package.swift
├── Lumi.xcodeproj
└── docs/
```

### 2.3 モジュール間の依存ルール

下位モジュールほど抽象的・上位モジュールほど具体的。**上位は下位に依存可能、下位から上位への依存は禁止**。

```
DesignSystem ← Models ← *Engine ← Infrastructure ← Feature ← App
```

#### 具体例
- ✅ `MatchInputFeature` は `Models`, `StatsEngine`, `LocalStore` に依存
- ✅ `StatsEngine` は `Models` に依存
- ❌ `Models` から `MatchInputFeature` への依存は禁止
- ❌ `StatsEngine` から `LocalStore` への依存は禁止（純粋関数を保つ）

## 3. TCA（The Composable Architecture）の使い方

### 3.1 基本構造

各 Feature は以下の構造：

```swift
@Reducer
public struct MatchInputFeature {
  @ObservableState
  public struct State: Equatable {
    var match: Match
    var currentRally: Rally?
    var inputMode: InputMode = .standard
    var error: AppError?
    // ...
  }
  
  public enum Action {
    case onAppear
    case playRecorded(Play)
    case undoRequested
    case rallyEnded(winner: Team)
    case errorReceived(AppError)
    // ...
  }
  
  @Dependency(\.localStore) var localStore
  @Dependency(\.syncEngine) var syncEngine
  @Dependency(\.statsEngine) var statsEngine
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .playRecorded(let play):
        // ...
        return .run { send in
          try await syncEngine.push(play)
        } catch: { error, send in
          await send(.errorReceived(.init(error)))
        }
      // ...
      }
    }
  }
}
```

### 3.2 Dependency Injection (TCA Dependencies)

すべての副作用（API/DB/時計等）は `@Dependency` で注入。テストで容易にモック化できる。

```swift
extension DependencyValues {
  var localStore: LocalStore {
    get { self[LocalStoreKey.self] }
    set { self[LocalStoreKey.self] = newValue }
  }
}

private enum LocalStoreKey: DependencyKey {
  static let liveValue: LocalStore = .live
  static let testValue: LocalStore = .test
  static let previewValue: LocalStore = .mock
}
```

### 3.3 状態管理の指針

- **試合中の State はメモリ + ローカル保存（10秒間隔）**
- **クラウド同期は副作用として非同期で**
- **State の更新は必ず Action 経由**（直接変更不可、TCAの基本）
- **ChildState/ChildAction の階層化**でモジュール分離を保つ

## 4. データ層の設計

### 4.1 SwiftData（ローカル）

ローカルの真実のソース。`@Model` クラスで定義：

```swift
@Model
final class Match {
  @Attribute(.unique) var id: UUID
  var teamId: UUID
  var matchCode: String
  // ...
  
  @Relationship(deleteRule: .cascade) var sets: [Set]
}
```

### 4.2 Supabase（クラウド）

PostgreSQLスキーマで対応するテーブル。RLS（Row Level Security）で：
- Teamの owner_id = auth.uid() のレコードのみアクセス可
- 試合コード経由のViewerは特定試合のみ読み取り可

### 4.3 ローカル ↔ クラウドの同期

詳細は `06_DATA_SYNC.md` を参照。

要点：
- 正本はクラウド
- ローカルは送信失敗時のバッファ
- 試合中の State はローカルに10秒ごとスナップショット（クラッシュ復元用）

## 5. 主要技術判断の理由

### 5.1 なぜ TCA か

**判断**：採用

**理由**：
- 状態管理が宣言的で、複雑な試合進行ロジックを記述しやすい
- 副作用が型レベルで管理され、テストが書きやすい
- TCA TestStore でアクション → 状態遷移を1対1で検証できる
- 個人開発でも長期メンテが可能な構造化を強制してくれる

**コスト**：
- 学習コスト（既に習得済みなら問題なし）
- ボイラープレートが多少増える

### 5.2 なぜ Supabase か（vs Firebase）

**判断**：Supabase 採用

**理由**：
- PostgreSQL ベース → SQLで柔軟集計可能（Phase 2の対戦相手DB等で活きる）
- Supabase Swift SDK は公式・成熟（v2.0+、4年開発）
- Free tier が個人開発に十分（DB 500MB、Realtime同時接続200）
- Row Level Security でマルチテナント対応がきれい
- Firebase ロックインを避けられる（Postgresなので移行容易）
- Sign in with Apple をネイティブサポート

**Firebaseの優位**：
- Swift SDKの歴史は長い（ただし Supabase も成熟）
- Crashlyticsが無料・無制限（→ Sentry の Free tier で代替可能）

### 5.3 なぜ SwiftData か（vs Core Data）

**判断**：SwiftData 採用

**理由**：
- iOS 17+で利用可能、本プロジェクトの最低OS（26）でフル機能利用可
- SwiftUIとの相性が良く、ボイラープレートが少ない
- Core DataのSwift wrapperとして将来性が高い
- マイグレーション機構も十分

### 5.4 なぜ Sentry か

**判断**：Sentry 採用

**理由**：
- Crashlytics に依存しない（Firebase不採用方針と整合）
- Free tier で 5,000イベント/月（個人開発に十分）
- パフォーマンス監視・リリーストラッキング統合
- Swift SDKは公式・成熟

## 6. 開発環境

### 6.1 推奨ツール

- Xcode 17+（iOS 26 SDK対応版）
- Swift 6.0+
- swift-format / SwiftLint（任意）

### 6.2 ローカル開発時の Supabase

- Supabase CLI でローカル開発環境構築
- `supabase start` で Docker内のPostgres起動
- マイグレーションは SQL ファイルで管理

### 6.3 環境変数管理

- `Config.swift` を生成（`.gitignore`）してSupabase URL/キーを管理
- 本番/Stagingで切り分け

## 7. CI/CD構成

### 7.1 GitHub Actions

`.github/workflows/ci.yml`：

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable
      - name: Build
        run: xcodebuild build -scheme Lumi ...
      - name: Test
        run: xcodebuild test -scheme Lumi ...
      - name: Snapshot Tests
        run: xcodebuild test -scheme SnapshotTests ...
      - name: Coverage Report
        run: xcrun llvm-cov export ...
```

### 7.2 TestFlight 自動配布（Phase 1.4以降）

- main ブランチへの push でビルド・TestFlight アップロード
- Fastlane または Xcode Cloud と連携

## 8. パフォーマンス目標

| 指標 | 目標値 |
|---|---|
| アプリ起動時間 | 2秒以内 |
| 1ラリー入力レスポンス | 100ms以内 |
| KPI計算（1試合分） | 200ms以内 |
| Supabase同期レイテンシ | 2秒以内（オンライン時） |
| PDF生成（1試合分） | 5秒以内 |
| メモリ使用量（試合中） | 200MB以下 |

## 9. セキュリティ・プライバシー

### 9.1 通信
- すべての通信はHTTPS/TLS
- Supabase接続はSSL強制
- 認証トークンはKeychainに保存

### 9.2 個人情報の扱い
- Phase 1：選手情報は自チームのみ・端末/Supabase保存
- Phase 2公開時：プライバシーポリシー作成・App Store審査対応
- 相手チーム名はマスキング機能を Phase 2.1 で実装

### 9.3 データ消去
- ユーザーがアカウント削除時：関連データすべて消去（GDPR/個人情報保護法対応）

## 10. 将来の拡張性

### 10.1 6人制対応の可能性
- データモデルは「フリーポジション前提」だが、ローテーション情報を追加すれば対応可能
- ただし設計を6人制汎用にしないこと（9人制最適化を妥協しない）

### 10.2 Web/Android対応
- Phase 1〜2 では考慮しない
- 必要になればKotlin Multiplatform検討（ただし現時点では非対象）

### 10.3 AIアシスト
- Phase 3+ で検討：自動プレー判定、自動コメント生成等
- 設計上は障害にならないよう、データを構造化して保存しておく
