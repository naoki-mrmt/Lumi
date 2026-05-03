# 08. Non-Functional Requirements — 非機能要件

## 1. パフォーマンス目標

| 指標 | 目標値 | 測定方法 |
|---|---|---|
| アプリ起動時間（コールドスタート） | 2秒以内 | Xcodeのインストルメント |
| 1ラリー入力レスポンス | 100ms以内 | Sentry Performance |
| KPI計算（1試合分） | 200ms以内 | 自動テストで計測 |
| Supabase同期レイテンシ（オンライン時） | 2秒以内 | E2Eテストで実測 |
| PDF生成（1試合分） | 5秒以内 | 自動テスト |
| メモリ使用量（試合中） | 200MB以下 | Xcodeのインストルメント |
| バッテリー消費（連続2時間使用） | 30%以下（iPad Pro想定） | 実戦テストで実測 |

### 1.1 セットアップ時間目標

| シナリオ | 目標時間 |
|---|---|
| 新規チーム・初回試合（マスタ登録から） | 10分以内 |
| 既存チーム・前回コピーあり | **2分以内**（理想：30秒） |
| 既存チーム・スタメン入れ替えあり | 3分以内 |

## 2. テスト戦略

### 2.1 テストレイヤと方針

| レイヤ | 内容 | 方針 | ツール |
|---|---|---|---|
| **L1: ロジック単体テスト** | KPI計算・サービス順算出・連続得点判定 | **必須・厚く書く（90%以上）** | Swift Testing |
| **L2: TCA Reducerテスト** | 状態遷移・副作用 | **重要箇所＋カバレッジ80%** | TCA TestStore |
| **L3: UIスナップショットテスト** | レイアウト崩れ検知 | **主要画面で導入** | swift-snapshot-testing |
| **L4: E2Eテスト** | 全体操作シナリオ | **Phase 1.4で重要フロー1〜2本** | XCUITest |

### 2.2 必ずテストすべき領域（具体）

#### KPI計算ロジック
- 境界値：0打数・全決定・全ミス
- 9人制特有：2回サーブ制・ブロック1接触
- アタック決定率・効果率の両方
- レセプションA率・返球率
- アシスト自動判定

#### サービス順自動算出
- セット間引き継ぎ
- 選手交代時の順番置換
- 連続得点時の同一サーバー継続
- 再交代制限

#### 3点以上連続得点ハイライト判定
- 境界値：2点連続→3点連続→中断→3点連続
- セット境界跨ぎの扱い

#### データ同期ロジック
- オフライン時のバッファリング
- 復帰時の送信順序
- 冪等性（同じプレーを2回送っても重複しない）
- 失敗時の指数バックオフ

### 2.3 スナップショットテストの方針

ライブラリ：[pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)

対象画面：
- 試合作成画面
- 入力画面（クイック/スタンダード/詳細の3モード）
- ベンチ閲覧画面（ライブビュー・振り返りビュー）
- PDFサマリレイアウト
- エラー画面（試合コード無効・オフライン等）

各画面で：
- iPad（横画面）ライト/ダーク
- iPhone（参考用、Phase 2用）

レコード初回生成 → 以降は差分でリグレッション検知。

### 2.4 カバレッジ目標

| レイヤ | 目標 |
|---|---|
| Models（データ定義） | 70%以上（Equatable等の自動コードを除く） |
| StatsEngine（KPI計算） | **90%以上** |
| ServiceOrderEngine | **95%以上**（バグ致命的） |
| RallyTimeline | 90%以上 |
| TCA Reducer | 80%以上 |
| UI層 | スナップショットでカバー、コードカバレッジは目標値設けない |

## 3. エラーハンドリング・障害時UX

### 3.1 エラーパターンと対応（Phase 1.0で全対応）

| # | パターン | 対応 |
|---|---|---|
| 1 | ネット一時切断 | Recorder：オフライン継続・小バナー警告。Viewer：「Recorderと未接続」表示 |
| 2 | Supabase書き込み失敗 | ローカルバッファに保留・指数バックオフで再送 |
| 3 | 試合コード誤入力 | リアルタイム検証・理由明示エラー |
| 4 | Recorder アプリクラッシュ | 起動時に「中断中の試合を復元しますか？」 |
| 5 | バッテリー切れ警告 | 残量20%以下で充電喚起バナー |
| 6 | iCloudバックアップ失敗 | 通知のみ・データは残る |
| 7 | Sign in with Apple失敗 | エラーメッセージ・メール認証へのフォールバック導線 |
| 8 | 同一試合に2人目Recorder | 後者を強制Viewer・メッセージ表示 |
| 9 | データ不整合 | バリデーションでブロック・修正導線 |
| 10 | アプリアップデート時のスキーマ変更 | マイグレーション自動実行・失敗時はバックアップ復元 |

### 3.2 重大度別の表現

| 重大度 | 表現 |
|---|---|
| 軽微（同期遅延等） | 上部の小バナー、自動消滅（5秒） |
| 中（部分的失敗） | トースト通知、操作続行可能 |
| 重大（試合継続不可） | モーダルダイアログ、復旧手段提示 |
| 致命的（クラッシュ） | クラッシュリポート送信、起動時に復元提示 |

### 3.3 グローバルエラーハンドリング設計

TCAアーキテクチャで `Error` を上位 Reducer に伝播：

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State {
    var error: AppError?
    // ...
  }
  
  enum Action {
    case errorReceived(AppError)
    case errorDismissed
  }
}

enum AppError: Error, Equatable {
  case network(NetworkError)
  case validation(ValidationError)
  case dataInconsistency(String)
  case unknown(String)
  
  var userMessage: String { /* 日本語メッセージ */ }
  var severity: Severity { /* 軽微/中/重大/致命的 */ }
}
```

すべての副作用（API呼び出し等）の失敗が `errorReceived` に集約され、UIは `state.error` を見てトーストやダイアログを出す。

## 4. 観測性（Observability）

### 4.1 3要素

| 要素 | 内容 | ツール |
|---|---|---|
| **Logs** | アプリ内ログ・操作履歴 | OSLog（Apple純正）+ Sentry breadcrumbs |
| **Metrics** | パフォーマンス・KPI | Sentry Performance |
| **Errors** | クラッシュ・例外 | Sentry |

### 4.2 Sentry の活用

- クラッシュ自動検知
- 重大エラーの手動キャプチャ：
  ```swift
  SentrySDK.capture(error: error) { scope in
    scope.setContext(value: ["match_id": matchId.uuidString], key: "match")
  }
  ```
- リリース別の問題追跡
- ユーザー識別（プライバシー考慮、display_nameのみ送信）

### 4.3 OSLog の活用

```swift
import OSLog

extension Logger {
  static let sync = Logger(subsystem: "com.muramoto-co.lumi", category: "sync")
  static let input = Logger(subsystem: "com.muramoto-co.lumi", category: "input")
  // ...
}

Logger.sync.info("Synced play: \(playId, privacy: .public)")
Logger.input.error("Failed to record play: \(error)")
```

## 5. ローカライズ

### 5.1 方針

- **Phase 1.0**：多言語化基盤を構築、提供は日本語のみ
- **Phase 2.4**：英語UIの翻訳を完成

### 5.2 実装方針

iOS 26 標準の **String Catalog**（`.xcstrings`）を使用：

```swift
// 文字列はすべてString(localized:)でラップ
Text(String(localized: "match.start", comment: "試合開始ボタン"))

// 数値・スコアフォーマット
Text(score, format: .number)
```

- `Localizable.xcstrings` に英語キーで管理
- 日本語訳をデフォルト言語として埋める
- 英語訳はPhase 2.4で追加

### 5.3 ローカライズ対象外

- **9人制バレーボール用語**：FL/FC/FR/HL/HC/HR/BL/BC/BR は専門用語として固定
- **選手名・チーム名・大会名**：ユーザー入力のためそのまま表示

## 6. アクセシビリティ

### 6.1 必須対応

- VoiceOver対応：すべての操作要素にアクセシビリティラベル
- Dynamic Type対応：本文要素はシステムフォント使用
- カラーコントラスト：WCAG AA（4.5:1以上）
- 色だけに依存しない：評価4段階は色 + アイコン（◎○△×）

### 6.2 推奨対応

- Reduce Motion 対応：アニメーションを最小化
- 代替テキスト：グラフ等にも要約テキスト

## 7. プライバシー・データ取扱い

### 7.1 個人情報の扱い

| データ | 扱い |
|---|---|
| 自チーム選手名 | 自チーム内のみ・端末/Supabase保存 |
| 相手チーム選手 | 背番号のみ（名前なし）・Phase 2.1で名前運用検討 |
| 自分のメールアドレス | Supabase Auth管理・Hide My Email対応 |
| プレーログ | 個人データの一部とみなす |

### 7.2 Phase 2.4公開時に必要

- プライバシーポリシー
- 利用規約
- App Store プライバシー栄養表示
- アカウント削除機能

### 7.3 データ消去ポリシー

- ユーザーがアカウント削除要求 → 関連データ全削除（GDPR/個人情報保護法対応）
- 試合削除前にローカルJSONバックアップ自動生成（誤削除対策）

## 8. コスト試算

### 8.1 Phase 1.0（自チーム利用）

| 項目 | 費用 | 備考 |
|---|---|---|
| Apple Developer Program | $99/年（約15,000円） | 加入済み |
| Supabase | $0 | Free tier内（DB 500MB / Realtime 200接続 / MAU 50,000） |
| Sentry | $0 | Free tier内（5,000イベント/月） |
| GitHub | $0 | パブリック or プライベート個人 |
| GitHub Actions | $0 | macOS minutes 無料枠で十分 |
| **合計** | **年約 15,000円** | |

### 8.2 Phase 2.4（公開・配布）

| 項目 | 費用 | 備考 |
|---|---|---|
| Apple Developer Program | $99/年 | 継続 |
| Supabase Pro | $25/月〜 | DB 8GB / 無制限スケール |
| Sentry Team | $26/月〜 | 必要に応じて |
| アプリアイコン・ASO | 0〜10万円 | デザイン外注なら |
| 法務（プライバシーポリシー等） | 0〜5万円 | 外注なら |
| **合計（運用次第）** | 年 60,000円〜 | |

## 9. CI/CD構成

### 9.1 GitHub Actions ワークフロー

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable
      
      - name: Resolve dependencies
        run: xcodebuild -resolvePackageDependencies
      
      - name: Build
        run: |
          xcodebuild build \
            -scheme Lumi \
            -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
      
      - name: Unit Tests
        run: |
          xcodebuild test \
            -scheme LumiTests \
            -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
            -resultBundlePath TestResults.xcresult
      
      - name: Snapshot Tests
        run: |
          xcodebuild test \
            -scheme SnapshotTests \
            -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v4
```

### 9.2 ブランチ戦略

- `main`：本番相当（リリースタグでバージョニング）
- `develop`：開発統合
- `feature/M{n}-*`：マイルストーン単位のフィーチャーブランチ

### 9.3 Phase 1.4以降：TestFlight自動配布

Fastlane または Xcode Cloud を導入：
- main ブランチへの push でビルド・TestFlight アップロード
- 自分のチームメンバーへ自動配布

## 10. ドキュメンテーション

### 10.1 コードコメント方針

- 公開API（public）：Swift DocC形式で説明
- 9人制ルールに関するロジック：「なぜこうなっているか」を明記
- 複雑な判定ロジック：参照する規則文書（JVAマニュアル等）をリンク

### 10.2 ドキュメント更新ルール

- 重要な設計判断 → `10_DESIGN_DECISIONS.md` に追記
- 進捗 → `progress.json` を毎セッション更新
- 機能追加・削除 → `02_FEATURE_SPEC.md` を更新
