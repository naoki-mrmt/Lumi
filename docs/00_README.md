# Lumi — 9-Volleyball Scouting App — Project Overview

> **Product Name**: Lumi  
> **App Store Subtitle**: Lumi — Volleyball Scouting  
> **Bundle Identifier**: `com.muramoto-co.lumi`

> **このドキュメントはClaude Codeが最初に読むエントリーポイントです。**
> セッション開始時は必ず `progress.json` と本ファイルを最初に読み、コンテキストを把握してから作業を開始してください。

---

## 1. プロジェクトの一行説明

**Lumi（リュミ）は、9人制バレーボール専用のスカウティングアプリ（iPad向け）。アナリストが試合中に入力したプレーデータをベンチでリアルタイムに確認でき、試合後の振り返り分析まで一貫して行える。**

> 「Lumi」はフランス語の lumière（光）に由来。データに光を当て、試合の本質を映し出す、という意図。

## 2. なぜ作るか

- **既存ツールの問題**：Data Volley等のリッチな分析ソフトは6人制前提でライセンス料が高い（年14万円）
- **9人制特有のニーズ**：ローテーションがない・サービス順管理・フォーメーション多様性などに対応した専用ツールが事実上存在しない
- **個人プロジェクト**：自チームで使い倒したい、将来的には公開も視野に

## 3. プロジェクトの最重要原則（Top 5）

これら5つは設計判断で迷った時の指針です。常に念頭に置いてください。

1. **9人制に最適化する**。6人制との差分（フリーポジション・サービス順・2回サーブ制・ブロック1接触等）を妥協しない
2. **データが主役、装飾は脇役**。エレガントなUIを目指すが、機能美を優先する
3. **アナリストもママさんも使える**。3段階の入力モード（クイック/スタンダード/詳細）で多様なユーザーに対応
4. **試合中は絶対に止まらない**。エラーハンドリング・オフライン対応・クラッシュリカバリを最初から作り込む
5. **プロダクトは段階的に成長させる**。Phase 1.0 MVPで実戦投入、その後Phase 1.1〜2.4で拡張

## 4. プロジェクト構成

```
lumi/
├── docs/                              ← ドキュメント類（CC が読む）
│   ├── 00_README.md                   ← 本ファイル：エントリーポイント
│   ├── 01_PRD.md                      ← 製品要求仕様
│   ├── 02_FEATURE_SPEC.md             ← 機能要件詳細（MUST/SHOULD/COULD）
│   ├── 03_DOMAIN_MODEL.md             ← 9人制ドメイン知識・データモデル
│   ├── 04_UI_DESIGN.md                ← 画面設計・デザインシステム
│   ├── 05_TECH_ARCHITECTURE.md        ← TCAマルチモジュール構造・技術選定
│   ├── 06_DATA_SYNC.md                ← Supabase連携・Recorder/Viewer・同期戦略
│   ├── 07_AUTH.md                     ← 認証・試合コード設計
│   ├── 08_NON_FUNCTIONAL.md           ← 非機能要件（パフォ・テスト・エラー処理・i18n・コスト）
│   ├── 09_ROADMAP.md                  ← Phase 1.0〜2.4 マイルストーン
│   ├── 10_DESIGN_DECISIONS.md         ← 設計判断ログ・なぜそう決めたか
│   ├── progress.json                  ← 進捗状況（CC が更新）
│   ├── progress.schema.json           ← progress.json の JSON Schema
│   └── tasks/                         ← マイルストーンごとのタスクチケット
│       ├── M0_setup.md
│       ├── M1_team_match_setup.md
│       ├── M2_input_core.md
│       ├── M3_stats_realtime.md
│       ├── M4_sync_auth.md
│       ├── M5_review_export.md
│       ├── M6_video_sync.md
│       ├── M7_error_handling.md
│       └── M8_observability.md
└── (Xcode project files / SPM modules — 未生成)
```

## 5. CC がセッション開始時にやること（必須ルーティン）

```
1. docs/progress.json を読む
   - current_milestone を確認
   - session_log[0]（最新）を確認
   - 「前回どこで止まったか」「次に何をすべきか」を把握

2. 現在のマイルストーンに対応する docs/tasks/Mx_*.md を読む

3. 必要に応じて関連ドキュメント（03_DOMAIN_MODEL, 05_TECH_ARCHITECTURE 等）を参照

4. 作業を開始

5. セッション中：
   - 重要な判断 → docs/10_DESIGN_DECISIONS.md と progress.json#decisions_log に記録
   - 不明点 → progress.json#open_questions に記録
   - タスク完了 → progress.json のタスクステータスを更新

6. セッション終了時：
   - progress.json#session_log の先頭に今日のサマリを追加
   - last_updated を更新
```

## 6. 技術スタック サマリ

| レイヤ | 採用 |
|---|---|
| 言語 | Swift |
| UI | SwiftUI |
| アーキテクチャ | TCA (The Composable Architecture) |
| パッケージ管理 | Swift Package Manager（マルチモジュール） |
| ローカル保存 | SwiftData |
| クラウド | Supabase（PostgreSQL + Realtime + Auth） |
| 認証 | Sign in with Apple |
| エラー観測 | Sentry |
| テスト | Swift Testing + TCA TestStore + swift-snapshot-testing |
| CI | GitHub Actions |
| 最低OS | iOS 26+ / iPadOS 26+ |

## 7. Phase 1.0 (MVP) スコープ サマリ

詳細は `09_ROADMAP.md` を参照。一行で：

> **「アナリストが iPad で入力 → ベンチ iPad で閲覧 → 試合後にPDF/CSV出力」を、9人制ルール完全対応で実現するMVP。**

期間目安：9〜12週間（CC主導）

## 8. プロジェクトメタ

| 項目 | 値 |
|---|---|
| 開発体制 | 個人開発・CC主導 |
| 主要ユーザー（Phase 1） | 自チーム（実業団・社会人 / ママさんバレー） |
| 主要ユーザー（Phase 2.4） | 公開・配布検討 |
| 配布方法 | TestFlight（Phase 1）→ App Store（Phase 2.4） |
| Apple Developer Program | 加入済み |
| 開発開始 | 2026-05 |

## 9. 重要な制約・前提

- **9人制特化**：6人制対応はスコープ外（将来要件として残しても、設計を妥協しない）
- **アナリスト想定**：2階席や俯瞰位置で iPad 入力を行う前提のUI設計
- **iPad中心**：Phase 1 では iPhone 対応しない（Phase 2.4 で再検討）
- **Recorder 1台 + Viewer 複数台**：入力者は1端末固定、閲覧は複数端末OK
- **オフライン耐性**：Recorder は完全オフラインで試合完遂可能、Viewer はネット必須

## 10. このドキュメント以降の読み順（推奨）

新規にプロジェクトを把握する場合：

```
00_README.md                    ← (今ここ)
01_PRD.md                       ← 何を作るかをまず把握
02_FEATURE_SPEC.md              ← 具体的な機能を確認
03_DOMAIN_MODEL.md              ← 9人制特有のデータモデル
04_UI_DESIGN.md                 ← UIの方向性
05_TECH_ARCHITECTURE.md         ← 技術構成
06_DATA_SYNC.md                 ← データ同期戦略
07_AUTH.md                      ← 認証
08_NON_FUNCTIONAL.md            ← 非機能要件
09_ROADMAP.md                   ← マイルストーン
10_DESIGN_DECISIONS.md          ← 設計判断の歴史

tasks/Mx_*.md                   ← 該当マイルストーンのタスク
```

実装を始める時：
- `progress.json` で現在地を確認 → `tasks/Mx_*.md` を読んで作業
