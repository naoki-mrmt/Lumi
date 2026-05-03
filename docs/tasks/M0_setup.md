# M0: プロジェクト基盤

## プロダクト情報（重要・最初に確認）

| 項目 | 値 |
|---|---|
| プロダクト名 | **Lumi** |
| App Store 副題 | Lumi — Volleyball Scouting |
| Bundle Identifier | `com.muramoto-co.lumi` |
| Xcode プロジェクト名 | `Lumi.xcodeproj` |
| ルートディレクトリ | `lumi/` |

## 目的

Lumi の Xcode/SPMプロジェクトを構築し、開発・テスト・CIの土台を作る。以降のマイルストーンが実装に集中できる「動く器」を完成させる。

## 前提

**M0-T1（Xcodeプロジェクト新規作成）はユーザーが手動で実施する**。`.xcodeproj` の新規作成はXcode GUIでの操作が確実なため。CCはM0-T2以降を担当。

ユーザーが実施する手順：
1. Xcode → New Project → iOS → App
2. Product Name: `Lumi`
3. Team: ユーザーのApple Developer アカウント
4. Organization Identifier: `com.muramoto-co`（→ Bundle ID自動的に `com.muramoto-co.lumi`）
5. Interface: SwiftUI / Language: Swift / Storage: SwiftData
6. Include Tests: チェック
7. 保存場所: `lumi/` ディレクトリ
8. Supported Destinations: iPad（必須）
9. Deployment Target: iOS 26.0
10. Git リポジトリ初期化（Xcode で「Create Git repository on my Mac」にチェック）

## 完了条件（DoD）

- [ ] Xcodeプロジェクト + SPMマルチモジュール構成が動作（empty appがビルド・起動可能）
- [ ] TCAが導入されAppFeatureが動作（empty Reducer / View）
- [ ] Supabase Swift SDKが導入され、初期化コードが動作する
- [ ] Sentry SDK が初期化され、テストエラーがダッシュボードに到達
- [ ] DesignSystem モジュールに DesignTokens（カラー・タイポグラフィ）の骨格
- [ ] String Catalog（`Localizable.xcstrings`）が用意され、最低1キーで日本語表示確認
- [ ] GitHub Actions の CI が push で動作（ビルド + 空のテストが緑）
- [ ] README.md にビルド手順・環境変数手順が記載

## 関連ドキュメント

- `docs/05_TECH_ARCHITECTURE.md` — SPM構成とモジュール依存ルール
- `docs/04_UI_DESIGN.md` — DesignSystemに入れる初期トークン
- `docs/08_NON_FUNCTIONAL.md` — CI/Sentry/i18nの方針
- `docs/00_README.md` — プロジェクト全体構造

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M0-T1 | Xcodeプロジェクト初期化 | **ユーザー手動実施**。iPad向けSwiftUIテンプレートでempty appを作成、シミュレータで起動 |
| M0-T2 | SPMマルチモジュール構成 | `Package.swift` で全モジュールを宣言、依存ルール（下位→上位禁止）を反映 |
| M0-T3 | TCAセットアップ | swift-composable-architectureを依存追加、AppFeatureが動作 |
| M0-T4 | Supabaseクライアント初期化 | supabase-swiftを依存追加、`SupabaseClient.shared`が初期化される |
| M0-T5 | DesignSystemモジュール骨格 | カラー・フォント拡張のスケルトン作成、Asset Catalog でカラー定義 |
| M0-T6 | GitHub Actions CI セットアップ | `.github/workflows/ci.yml` でビルド・テスト実行、緑バッジ |
| M0-T7 | Sentry SDK 統合 | sentry-cocoaを依存追加、`SentrySDK.start`実行、テストイベント到達 |
| M0-T8 | String Catalog 基盤 | `Localizable.xcstrings`を用意、1キーで日本語動作確認 |

## 実装メモ

### SPMモジュール設計（再掲・抜粋）

```
Sources/
├── AppFeature/                ← App.swift から呼ぶルート
├── MatchSetupFeature/
├── MatchInputFeature/
├── MatchViewerFeature/
├── ReviewFeature/
├── TeamManagementFeature/
├── AuthFeature/
├── Models/                    ← 純粋ドメイン
├── StatsEngine/
├── ServiceOrderEngine/
├── RallyTimeline/
├── LocalStore/
├── SupabaseClient/
├── Sync/
├── PDFGenerator/
├── VideoSync/
├── DesignSystem/
└── Telemetry/
```

各モジュールは `Package.swift` で `target` として宣言し、依存を明示。

### 依存追加リスト

```swift
.package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
.package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
.package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0"),
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),  // テスト用
```

### Sentry初期化

```swift
SentrySDK.start { options in
  options.dsn = AppConfig.sentryDSN
  options.environment = AppConfig.environment  // "development" / "production"
  options.tracesSampleRate = 1.0
  options.attachScreenshot = false  // プライバシー考慮
  options.attachViewHierarchy = false
}
```

### `.gitignore` 必須エントリ

```
xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
.swiftpm/
Config.swift     # Supabase/Sentry のキー類
.env
```

`Config.swift` は別途 `Config.swift.template` を用意して、各開発者が自分で作る方式。

## CC に渡すプロンプト雛形

```
M0 を進めてほしい。
docs/00_README.md と docs/progress.json を読んで現在地を確認した上で、
docs/05_TECH_ARCHITECTURE.md の SPMマルチモジュール構成に従って、
M0-T1 から順番に進めてほしい。

各タスク完了ごとに：
1. progress.json の該当タスクを completed にする
2. last_updated を更新する
3. 次のタスクに進む前に1度報告する

完了条件は docs/tasks/M0_setup.md を参照。
```
