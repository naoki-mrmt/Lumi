<div align="center">

# Lumi

**9人制バレーボール スカウティング iPad アプリ**

*Lumière — データに光を当て、試合の本質を映し出す。*

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iPadOS%2026%2B-lightgrey.svg)](#)

</div>

---

Lumi は **9人制バレーボール専用** のスカウティングアプリです。試合中の入力 (Recorder) からリアルタイム閲覧 (Viewer)、試合後の振り返り (PDF/CSV)、シーズン累計レポートまでを一台の iPad で完結させます。

> [!NOTE]
> 9人制は 6 人制とは別のルール体系です。サーブ 2 本制、フリーポジション、21 点制、ブロックタッチを 1 回にカウント、再交代制限など、9 人制特有のロジックを正確に実装しています。

## 主な特徴

### 試合中 (Recorder)

- **3 モード入力切替** — クイック / 標準 / 詳細
- **コートタップ + プレー種別ボタン** のハイブリッド UI
- **信号機メタファー** の評価4段階 (◎ / ○ / △ / ×)
- **5 ステップアンドゥ** + **直前ラリー編集**
- **Haptic Feedback** (iOS 26 SensoryFeedback API)
- **オフライン完全対応** — ネット切断中も入力継続、復帰時に自動同期 (指数バックオフ再送)
- **10 秒スナップショット** + 起動時クラッシュ復元

### リアルタイム同期 (Viewer)

- **Supabase Realtime** で試合コードのみで参加可能
- 6 桁試合コード (紛らわしい文字を除外)
- Recorder 衝突防止 (current_recorder_device_id ベース)

### KPI ダッシュボード

- アタック決定率 / 効果率、レセプション A 率、サーブ効率、ブロック・ディグ・アシスト
- **Swift Charts** による得点推移グラフ + TO マーカー + 連続得点ハイライト
- セット別 / 選手別 / フォーメーション別フィルタ

### 振り返り・出力

- **PDF**: 試合サマリ / スカウトレポート / シーズン累計
- **CSV**: 選手別集計 / 全プレーログ
- **iOS 共有シート** (AirDrop / メール / Files)
- **JSON バックアップ** (削除前自動生成)

### 将来機能 (Phase 2)

- 動画後付け同期 (プレー → AVPlayer seek)
- **6 秒遅延映像配信** (Apple 純正 MultipeerConnectivity、追加コスト 0)
- 対戦相手 DB + ブリーフィング画面
- 選手個人マイページ

## クイックスタート

```bash
git clone https://github.com/naoki-mrmt/Lumi.git
cd Lumi
make bootstrap          # Config.swift 作成 + SPM resolve
# Lumi/Config.swift に Supabase URL / anon key / Sentry DSN を記入
make build              # iPad Simulator 向けビルド
make test               # SPM 全テスト
```

詳細な手順は [docs/00_README.md](docs/00_README.md) と [`make help`](Makefile) を参照。

## 必要環境

| 要件 | バージョン |
|---|---|
| macOS | 14+ |
| Xcode | 26+ (iOS 26 SDK) |
| Swift | 6.x |
| iPad | iPadOS 26+ |
| (任意) Supabase CLI | latest |
| (任意) Deno | v2.x (Edge Functions) |

## アーキテクチャ

SPM マルチモジュール構成。**Domain 層は完全に副作用なし**、Feature 層は TCA、Infrastructure 層は protocol で抽象化されてテスト可能。

```
App (Lumi.xcodeproj target)
├── AppFeature                    ルート TCA Reducer
├── Features (TCA Reducer + View)
│   ├── MatchSetupFeature, MatchInputFeature, MatchViewerFeature
│   ├── ReviewFeature, TeamManagementFeature, AuthFeature
│   └── ReportFeature, OpponentDatabaseFeature, VideoReviewFeature,
│       PlayerPageFeature, VideoStreamFeature,
│       EmailAuthFeature, TeamSwitcherFeature, LegalFeature
├── Domain (純粋 Swift・副作用なし)
│   Models / StatsEngine / ServiceOrderEngine / RallyTimeline / Validators
├── Infrastructure
│   LocalStore (SwiftData) / SupabaseClient / Sync
│   PDFGenerator / CSVExporter / MatchBackup / VideoSync
└── Core
    DesignSystem / Telemetry
```

詳細: [docs/05_TECH_ARCHITECTURE.md](docs/05_TECH_ARCHITECTURE.md)

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [`docs/00_README.md`](docs/00_README.md) | エントリポイント・読む順番 |
| [`docs/01_PRD.md`](docs/01_PRD.md) | プロダクトビジョン・ペルソナ |
| [`docs/02_FEATURE_SPEC.md`](docs/02_FEATURE_SPEC.md) | MoSCoW 機能分類 |
| [`docs/03_DOMAIN_MODEL.md`](docs/03_DOMAIN_MODEL.md) | 9 人制ルール + データモデル |
| [`docs/04_UI_DESIGN.md`](docs/04_UI_DESIGN.md) | デザイン原則・ワイヤー |
| [`docs/05_TECH_ARCHITECTURE.md`](docs/05_TECH_ARCHITECTURE.md) | 技術選定・SPM 構成 |
| [`docs/06_DATA_SYNC.md`](docs/06_DATA_SYNC.md) | 同期戦略・Supabase スキーマ |
| [`docs/07_AUTH.md`](docs/07_AUTH.md) | Sign in with Apple 設計 |
| [`docs/08_NON_FUNCTIONAL.md`](docs/08_NON_FUNCTIONAL.md) | 非機能要件 |
| [`docs/09_ROADMAP.md`](docs/09_ROADMAP.md) | フェーズ別ロードマップ |
| [`docs/10_DESIGN_DECISIONS.md`](docs/10_DESIGN_DECISIONS.md) | ADR (Architecture Decision Records) |
| [`docs/specs/`](docs/specs/) | マイルストーン別仕様書 |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | 開発参加ガイド |

## 技術スタック

- **UI**: SwiftUI + Swift Charts + AVKit
- **アーキテクチャ**: [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) 1.25.x
- **永続化**: SwiftData (ローカル) + [Supabase](https://supabase.com) (クラウド)
- **認証**: Sign in with Apple + Supabase Auth
- **観測性**: [Sentry](https://sentry.io) + OSLog
- **テスト**: Swift Testing (`@Test`) + TCA TestStore + swift-snapshot-testing
- **CI**: GitHub Actions (Swift / iOS / SQL lint / Deno typecheck / gitleaks)
- **配信 (Phase 2.3)**: MultipeerConnectivity (Apple 純正、追加コスト 0)

## デザイン哲学

> 「沈黙のスカウティングツール」 — データそのものを主役に。

- **ダークモード優先** (体育館の薄暗い環境 / バッテリー考慮)
- **Tabular Numbers 徹底** で数値が揃う
- **アニメーションは情報伝達のみ** (装飾的バウンスは禁止)
- **ワンタップで戻れる、ワンタップで取り消せる**

詳細: [docs/04_UI_DESIGN.md](docs/04_UI_DESIGN.md)

## 開発参加

PR / Issue は歓迎します。コーディング規約・ブランチ戦略・コミット規約は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

```bash
# 開発フロー
git checkout -b feature/xxx
make test
git commit -m "feat(ios): 新機能の概要"
gh pr create
```

## ライセンス

[GNU Affero General Public License v3.0](LICENSE)

派生物を **配布またはネットワーク提供** する場合、ソースコードを同一ライセンスで公開する義務があります (AGPL の特徴)。詳細は LICENSE 全文を参照。

商用利用・別ライセンスでの利用については、作者にご相談ください。

## 連絡先

作者: 村本 直樹 (`muramoto@swooo.net`)

---

<div align="center">

Made with ❤️ for the 9-player volleyball community.

</div>
