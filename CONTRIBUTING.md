# Contributing to Lumi

Lumi への貢献を歓迎します。

## 開発環境

| 要件 | バージョン |
|---|---|
| macOS | 14+ |
| Xcode | 26+ (iOS 26 SDK) |
| Swift | 6.x |

(任意)

| 要件 | バージョン |
|---|---|
| Supabase CLI | latest |
| Deno | v2.x |
| SQLFluff | 3.x |

## 初回セットアップ

```bash
git clone https://github.com/naoki-mrmt/Lumi.git
cd Lumi
make bootstrap
# Lumi/Config.swift を編集して Supabase URL / anon key / Sentry DSN を記入
```

## ブランチ戦略

- `main` — 本番ブランチ
- `develop` — 開発統合ブランチ
- `feature/xxx` — 新機能
- `fix/xxx` — バグ修正

PR は `develop` 向けに作成してください (主要リリース時に `main` へマージ)。

## コミット規約 (Conventional Commits)

```
feat(ios): 新機能
fix(ios): バグ修正
test(ios): テスト追加
test(kit): SPM モジュールテスト
docs: ドキュメント更新
refactor: リファクタリング
chore: 雑務
```

## コーディング規約

### 言語

- **コード・変数名・コミット・型定義・スキーマ**: 英語
- **ドキュメント・UI・コメント**: 日本語

### TDD 必須

すべての実装はテスト駆動。

1. **Red** — 失敗するテストを先に書く
2. **Green** — テストを通す最小実装
3. **Refactor** — テスト維持のまま改善

### テスト対象

- ✅ Domain 層 (最重要・最多): Swift Testing + Protocol 準拠テスト
- ✅ TCA Feature: TestStore + `@Dependency` override
- ✅ Persistence: インメモリ ModelContainer
- ❌ 純粋な View (SwiftUI Preview で確認)
- ❌ 外部ライブラリの薄いラッパー

### TCA パターン

- Feature = `@Reducer` + View のペア
- `@ObservableState` for State
- `@Dependency` で外部依存注入
- Effect 内エラーは Action で伝播
- Domain 層は TCA 非依存 — Protocol で抽象化

詳細: [`docs/05_TECH_ARCHITECTURE.md`](docs/05_TECH_ARCHITECTURE.md)

### SwiftUI / SwiftData 注意点

- `NavigationStack` を使う (`NavigationView` 非推奨)
- `@Observable` を使う (`@ObservedObject` 不使用)
- `.task {}` で async 処理 (`onAppear` で async しない)
- `@Model` class は MainActor 上で操作
- `ModelContainer` は起動時に 1 回だけ生成
- SwiftData が唯一の永続化手段 (UserDefaults / CoreData 不使用)

## ドキュメントファースト

実装前に必ず `docs/specs/` に仕様書を作成してください。

```
docs/specs/M{0-8}_*.md          — マイルストーン別 spec
docs/specs/feature-name.md      — 個別機能の spec
```

## ビルド & テスト

```bash
make help            # 一覧
make build           # iPad Simulator 向けビルド
make test            # SPM 全テスト
make spm-build       # SPM のみで build
make clean           # .build / DerivedData 削除
```

### Supabase ローカル開発

```bash
make db-start        # ローカル Supabase 起動 (Docker)
make db-reset        # migrations + seed で初期化
make functions-serve # Edge Functions ローカル起動
```

## CI

PR / push で以下が自動実行:

- `swift-test`: macOS で全 SPM テスト
- `ios-build`: iPad Simulator 向けビルド
- `sql-lint`: sqlfluff で migrations を lint
- `edge-functions-typecheck`: Deno で typecheck
- `secret-scan`: gitleaks で秘密情報の混入チェック

詳細: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

## 公開リポでの注意

このリポジトリは公開されています。**シークレットを絶対にコミットしないでください**。

### コミットしてはいけないもの

- `Lumi/Config.swift` (Supabase URL / anon key / Sentry DSN)
- `.env` / `.env.local`
- `*.p8` / `*.p12` / `*.mobileprovision`
- Apple Developer / App Store Connect の API キー
- Supabase Service Role Key
- Sentry の管理シークレット

すべて `.gitignore` 済みですが、`git add -f` で強制追加しないこと。

### CI で利用する Secrets

GitHub Settings > Secrets and variables > Actions に登録:

| 名前 | 用途 |
|---|---|
| `SUPABASE_PROJECT_REF` | デプロイ先プロジェクト ID |
| `SUPABASE_ACCESS_TOKEN` | supabase CLI |
| `SUPABASE_DB_PASSWORD` | DB 接続 |
| `APPSTORE_CONNECT_API_KEY_*` | TestFlight 配信 |
| `APPLE_CERTIFICATE_BASE64` | 署名用証明書 |

### 誤コミット時の対応

1. 該当鍵 / トークンを **直ちに失効** (Supabase / Apple Developer / Sentry の管理画面)
2. 新しい値を発行して `.env` に記入
3. 必要なら `git filter-repo` で履歴から除去
4. `make secrets-scan` で再確認

## ライセンスについて

このプロジェクトは [GNU AGPL v3.0](LICENSE) です。コントリビュートいただいたコードも同ライセンスで公開されます。

## 質問・連絡

- バグ報告・機能要望: GitHub Issues
- セキュリティ問題: 公開 Issue にせず `muramoto@swooo.net` までメール
- 一般質問: GitHub Discussions
