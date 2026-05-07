# Supabase セットアップ手順

## 1. Supabase プロジェクト作成

[https://supabase.com](https://supabase.com) でプロジェクトを作成し、URL と Anon Key を取得。

## 2. マイグレーション適用

ローカル開発時:

```bash
brew install supabase/tap/supabase
supabase init
supabase link --project-ref <YOUR_REF>
supabase db push
```

または Supabase Dashboard > SQL Editor で `migrations/` 内のファイルを **連番順** に実行:

1. `0001_initial_schema.sql` — テーブル定義
2. `0002_rls_policies.sql` — Row Level Security
3. `0003_indexes.sql` — インデックス
4. `0004_realtime_publication.sql` — Realtime 有効化

## 3. Authentication 設定

Dashboard > Authentication > Providers > Apple を有効化。

- Service ID, Team ID, Key ID, Private Key を Apple Developer Portal から取得して登録

## 4. Config.swift 配置

リポジトリの `Config.swift.template` をコピーして `Lumi/Config.swift` を作成 (.gitignore 済み):

```swift
enum Config {
    static let supabaseURL = "https://<YOUR_PROJECT>.supabase.co"
    static let supabaseAnonKey = "<YOUR_ANON_KEY>"
    static let sentryDSN = "<YOUR_SENTRY_DSN>"
}
```

## 5. RLS の動作確認

`auth.uid()` が異なる別ユーザーで teams を読み出して 0 件であること。
