# CLAUDE.md — Lumi

## プロジェクト概要
**Lumi** — 9人制バレーボール専用スカウティングアプリ (iPad)
- Bundle ID: `com.muramoto-co.lumi`
- 名前の由来: フランス語 lumière（光）。データに光を当て、試合の本質を映し出す
- 個人開発プロジェクト、Phase 1.0 (MVP) 開発中

## ドメイン知識 (9人制バレーボール)
6人制とは別競技。以下が実装上の重要ポイント:
- **ローテーションなし** — フリーポジション制
- **サーブ2本制** — 1本目失敗→2本目、2本目失敗→サイドアウト
- **ブロックタッチ = 1回** — 3回のうち1回を消費（6人制は回数外）
- **21点制** (20-20でデュース、2点差)
- **ネットインサーブ = フォルト**
- **サービスオーダー** — 試合前に固定、セット中変更不可。交代時は位置を継承
- **交代** — 1セット最大4回、1回の交代で最大3人、再交代は1セット1回まで

## 技術スタック
| レイヤー | 技術 |
|---------|------|
| UI | SwiftUI (iPad横画面専用) |
| アーキテクチャ | TCA (Composable Architecture) 1.25.x |
| ローカルDB | SwiftData (唯一の永続化手段) |
| クラウド | Supabase (PostgreSQL + Realtime) |
| 認証 | Sign in with Apple + Supabase Auth |
| 監視 | Sentry + OSLog |
| テスト | Swift Testing (`@Test`) + TCA TestStore + swift-snapshot-testing |
| CI | GitHub Actions |
| 最低OS | iOS 26+ / iPadOS 26+ |

## アーキテクチャ
```
App (エントリポイント)
├── Feature Modules (TCA Reducer + View)
│   MatchSetup / MatchInput / MatchViewer / Review / TeamManagement / Auth
├── Domain Modules (純粋Swift、副作用なし)
│   Models / StatsEngine / ServiceOrderEngine / RallyTimeline / Validators
├── Infrastructure Modules
│   LocalStore / SupabaseClient / Sync / PDFGenerator / VideoSync
└── Core / DesignSystem
    Colors / Fonts / Components / Logger
```

## ビルド & テスト
```bash
# Xcodeプロジェクトビルド
xcodebuild -project Lumi.xcodeproj -scheme Lumi build

# テスト実行
xcodebuild -project Lumi.xcodeproj -scheme Lumi test

# SPMモジュールテスト (構成後)
# cd Packages/LumiKit && swift test
```

## 開発規約

### 言語ルール
- コード・変数名・コミット・型定義・スキーマ: **英語**
- ドキュメント・UI・コメント: **日本語**

### TDD必須
すべての実装はテスト駆動。例外なし。
1. Red — 失敗するテスト
2. Green — 最小実装
3. Refactor — テスト維持のまま改善

### ドキュメントファースト
実装前に `/spec` で `docs/specs/` に仕様書を作成。仕様書なしの実装開始は禁止。

### コミット規約 (Conventional Commits)
```
feat(ios): / fix(ios): / test(kit): / docs: / refactor: / chore:
```

### ブランチ戦略
- `main` — 本番
- `develop` — 開発統合
- `feature/xxx` — 機能開発
- `fix/xxx` — バグ修正

### エラーハンドリング
- Swift Result型 + async/await
- 日本語エラーメッセージ（ユーザー向け）

### セキュリティ
- APIキー (Supabase等) はクライアントに露出させない
- シークレットはリポジトリにコミットしない

## TCA パターン
- Feature = `@Reducer` + View のペア
- `@ObservableState` for State
- `@Dependency` で外部依存注入、TestStore + override で検証
- Domain層は TCA 非依存 — Protocol で抽象化
- Effect内エラーは Action で伝播

## SwiftUI / SwiftData 注意点
- `NavigationStack` 使用 (NavigationView 非推奨)
- `@Observable` 使用 (`@ObservedObject` 不使用)
- `.task {}` で async 処理 (`onAppear` で async しない)
- `@Model` class は MainActor 上で操作
- ModelContainer は起動時に1回だけ生成
- SwiftData が唯一の永続化手段 (UserDefaults, CoreData 不使用)

## デザイン哲学
- **ダークモード基本** (体育館照明・バッテリー)
- **データが主役**、装飾は二の次
- **信号機メタファー**: ◎緑 / ○シアン / △黄 / ×赤
- **SF Pro Rounded** (スコア) / **SF Pro Display** (見出し) / **SF Mono** (統計値)
- アニメーションは情報伝達目的のみ

## パフォーマンス目標
| 指標 | 目標 |
|------|------|
| アプリ起動 | < 2秒 |
| 1ラリー入力応答 | < 100ms |
| KPI計算 (全試合) | < 200ms |
| Supabase同期遅延 | < 2秒 |
| メモリ (試合中) | < 200MB |
| テストカバレッジ (ロジック) | > 90% |

## セッション間の継続
- `docs/progress.json` — 進捗・タスク状態・意思決定ログ・セッション記録 (`progress.schema.json` で検証)
- セッション開始時に必ず `progress.json` と該当マイルストーンタスクファイルを確認
- 作業中はタスクステータスを更新、セッション終了時に `session_log` に要約を追記

## ドキュメント構成
```
docs/
├── 00_README.md        — エントリポイント・読む順番
├── 01_PRD.md           — プロダクトビジョン・ペルソナ
├── 02_FEATURE_SPEC.md  — MoSCoW機能分類
├── 03_DOMAIN_MODEL.md  — 9人制ルール・データエンティティ・KPI式
├── 04_UI_DESIGN.md     — デザイン原則・レイアウト・色・Haptics
├── 05_TECH_ARCHITECTURE.md — 技術選定・SPM構成・依存関係
├── 06_DATA_SYNC.md     — 同期設計
├── 07_AUTH.md          — 認証設計
├── 08_NON_FUNCTIONAL.md — 非機能要件
├── 09_ROADMAP.md       — フェーズ別ロードマップ
├── 10_DESIGN_DECISIONS.md — ADR (27件)
├── progress.json       — 進捗管理 (JSON Schema検証済)
└── tasks/M{0-8}_*.md   — マイルストーン別タスク詳細
```

## スキルワークフロー
- `/spec <feature>` — 仕様書作成 → `docs/specs/`
- `/ios-impl <spec>` — 仕様書から TDD 実装 (Domain → Persistence → Feature)
- `/verify` — ビルド・テスト・品質チェック
- `/ship` — コミット + PR (汎用)
- `/ship-ios` — Xcodeビルド検証付きコミット + PR
- `/review` — コードレビュー
- `/eng-review` — エンジニアリング観点レビュー
- `/plan` — 実装計画策定
- `/sprint` — スプリント管理
- `/retro` — 振り返り
