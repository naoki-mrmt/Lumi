# Lumi 本番環境セットアップ手順書

このドキュメントでは、Lumi を実際の Supabase / Apple Developer / Sentry / StoreKit 環境に接続し、TestFlight 配信や App Store 審査に進むための手順をまとめている。所要時間は 60〜90 分。

> **重要**: 本リポは公開前提のため、すべての秘匿情報は `Config.local.xcconfig` または `.env` (どちらも .gitignore 済) に閉じ込め、リポジトリには絶対にコミットしないこと。`make secrets-scan` で確認可能。

---

## 0. 前提

| ツール | バージョン | 用途 |
|---|---|---|
| Xcode | 26.5 Beta 3 | iOS 26 SDK / iPad Pro M5 シミュレータ |
| Supabase CLI | 1.180+ | DB マイグレーション・Edge Functions デプロイ |
| Apple Developer Program | 有償加入済み | Sign in with Apple, App Store 配信 |
| Node.js | 18+ | Supabase CLI / Edge Functions ローカル実行 |
| Sentry CLI (任意) | 最新 | リリース管理 |

```bash
# Supabase CLI インストール
brew install supabase/tap/supabase

# Node.js (mise / asdf / nvm 任意)
brew install node
```

---

## 1. Supabase プロジェクトの作成

### 1.1 Web ダッシュボードからプロジェクト作成

1. <https://supabase.com/dashboard/projects> にアクセス
2. **New project** をクリック
3. 入力:
   - Name: `lumi-prod` (または `lumi-staging` で stg を切ってもよい)
   - Database password: 強固な値を `1Password` 等に保存
   - Region: `Northeast Asia (Tokyo)` を推奨
   - Pricing: Free でも開始可。Realtime / Storage の使用量を見て Pro へ
4. プロジェクト作成完了後、**Project Settings → API** から以下を取得:
   - `Project URL` (例: `https://xxxxxxxx.supabase.co`)
   - `anon public` key
   - `service_role` key (サーバ専用、クライアントに渡さない)

### 1.2 ローカル CLI とリンク

```bash
# Supabase アカウントにログイン (ブラウザが開く)
supabase login

# プロジェクトのプロジェクト ID (URL の xxxxxxxx 部分) でリンク
supabase link --project-ref <PROJECT_REF>
```

### 1.3 マイグレーションを本番に適用

```bash
# 既存 supabase/migrations/*.sql を本番 DB に適用
make db-push
# = supabase db push
```

`supabase/migrations/` 配下にある SQL を順次実行する。失敗時はエラー文を読んで該当 migration を修正。

### 1.4 Edge Functions をデプロイ

```bash
make functions-deploy
# = supabase functions deploy viewer-session
#   supabase functions deploy cleanup-expired-codes --no-verify-jwt
#   supabase functions deploy delete-account
```

### 1.5 Edge Functions 用シークレットを登録

Edge Functions が利用する秘密値を Supabase 側に登録する。クライアント (アプリ) には渡らない。

```bash
# Viewer の試合コード署名用 JWT 秘密鍵 (32文字以上のランダム文字列)
supabase secrets set LUMI_VIEWER_JWT_SECRET="$(openssl rand -base64 48)"

# 期限切れコード掃除 cron の認証用
supabase secrets set CRON_SECRET="$(openssl rand -base64 32)"
```

設定済みのキー一覧を確認:
```bash
supabase secrets list
```

### 1.6 Realtime / Storage の有効化確認

- Dashboard → **Database → Replication** で `plays`, `rallies`, `timeouts`, `substitutions`, `match_sets` が publication に含まれているか確認 (`supabase/migrations/0004_realtime_publication.sql` で設定済み)
- Storage は Phase 2.2 (動画) で利用予定。今は触らなくてよい

---

## 2. Sign in with Apple のセットアップ

Apple Developer アカウントが必要。下記は Apple 公式手順 (<https://developer.apple.com/sign-in-with-apple/get-started/>) を Lumi 用に簡略化したもの。

### 2.1 App ID 登録

1. <https://developer.apple.com/account/resources/identifiers/list> を開く
2. **+ ボタン → App IDs → App** で新規作成
3. 入力:
   - Description: `Lumi`
   - Bundle ID: `com.muramoto-co.lumi` (Explicit)
   - Capabilities: **Sign In with Apple** にチェック
4. **Continue → Register**

### 2.2 Service ID 作成 (Supabase が Web OAuth として使う)

1. **+ ボタン → Services IDs**
2. 入力:
   - Description: `Lumi Web Auth`
   - Identifier: `com.muramoto-co.lumi.signin` (Bundle ID とは別)
3. 作成後、リスト上で Service ID をクリック → **Sign in with Apple** にチェック → **Configure**
4. Configure ダイアログで:
   - Primary App ID: `com.muramoto-co.lumi`
   - Domains and Subdomains: `<PROJECT_REF>.supabase.co`
   - Return URLs: `https://<PROJECT_REF>.supabase.co/auth/v1/callback`
5. Save → Continue → Register

### 2.3 Sign in with Apple 用 Key を作成

1. 左メニュー **Keys → +**
2. 入力:
   - Key Name: `Lumi Sign In Apple Key`
   - **Sign in with Apple** にチェック → **Configure** で Primary App ID = `com.muramoto-co.lumi`
3. Continue → Register
4. **`.p8` ファイルをダウンロード** (`AuthKey_XXXXXXXXXX.p8`)。**1度しかダウンロードできないので失くさないよう保管**
5. Key ID と Team ID をメモ (Apple Developer のアカウント詳細から確認可能)

### 2.4 Apple OAuth 用 JWT (client secret) を生成

Supabase は Sign in with Apple 用に "client secret" として ES256 署名済み JWT を要求する。下記スクリプトで生成:

```bash
# scripts/gen_apple_jwt.sh のような形で保存しておくと便利
TEAM_ID="YOURTEAMID"
KEY_ID="YOURKEYID"
SERVICE_ID="com.muramoto-co.lumi.signin"
P8_FILE="AuthKey_${KEY_ID}.p8"

NOW=$(date +%s)
EXP=$((NOW + 15777000))   # 約半年 (Apple は最大6ヶ月)

# header
header_json='{"alg":"ES256","kid":"'"${KEY_ID}"'","typ":"JWT"}'
header=$(printf '%s' "${header_json}" | openssl base64 -A | tr '+/' '-_' | tr -d '=')

# payload
payload_json='{"iss":"'"${TEAM_ID}"'","iat":'"${NOW}"',"exp":'"${EXP}"',"aud":"https://appleid.apple.com","sub":"'"${SERVICE_ID}"'"}'
payload=$(printf '%s' "${payload_json}" | openssl base64 -A | tr '+/' '-_' | tr -d '=')

# signature
sig=$(printf '%s' "${header}.${payload}" | openssl dgst -sha256 -sign "${P8_FILE}" | openssl base64 -A | tr '+/' '-_' | tr -d '=')

echo "${header}.${payload}.${sig}"
```

出力された `eyJ....eyJ....xxx` が Apple OAuth client secret。

### 2.5 Supabase 側の Apple OAuth 設定

1. Supabase Dashboard → **Authentication → Providers**
2. **Apple** を **Enabled** に
3. 入力:
   - **Client IDs**: `com.muramoto-co.lumi.signin` (Service ID)
   - **Secret Key (for OAuth)**: 2.4 で生成した JWT 全体
4. **Save**

### 2.6 Xcode 側に capability を追加

Xcode で `Lumi` ターゲットを選択 → **Signing & Capabilities → + Capability → Sign in with Apple** を追加。

---

## 3. Sentry プロジェクト作成

1. <https://sentry.io/organizations/-/projects/new/> で **iOS** プロジェクトを作成
2. プロジェクト名: `lumi-ios`
3. 作成完了後、**Settings → Client Keys (DSN)** から `DSN` をコピー
4. Source Maps / dSYM のアップロードは Phase 1.0 では skip 可。リリース時に有効化

---

## 4. クライアント側 Config 設定 (xcconfig 経由)

### 4.1 Config.local.xcconfig の作成 (一度きり)

```bash
make bootstrap
# = cp Config.local.xcconfig.template Config.local.xcconfig
```

エディタで `Config.local.xcconfig` を開いて値を埋める:

```
SUPABASE_URL = https:/$()/<PROJECT_REF>.supabase.co
SUPABASE_ANON_KEY = <ANON_KEY>
SENTRY_DSN = https:/$()/<KEY>@sentry.io/<PROJECT_ID>
```

> **xcconfig 構文の罠**: xcconfig では `:` の後の `//` がコメント開始扱いされる。
> URL は `https:/$()/...` のように `$()` (空変数評価) を挟んで `//` を分断する。

> **誤コミット防止**: `Config.local.xcconfig` は `.gitignore` 済。`make secrets-scan` でも検出可。

### 4.2 値の流れ (自動)

```
Config.local.xcconfig  (gitignore)
        ↓ #include?
Config.xcconfig        (committed、デフォルトは空)
        ↓ baseConfigurationReference
Lumi.xcodeproj         (Debug + Release 両方)
        ↓ Info.plist の $(SUPABASE_URL) を変数展開
Info.plist             (リポ root、committed)
        ↓ Bundle.main.object(forInfoDictionaryKey:)
AppConfig.supabaseURL  (SupabaseClient/SupabaseClientModule.swift)
        ↓ SupabaseClientProvider.shared
Live SDK / Mock fallback (未設定時)
```

`Config.local.xcconfig` がリポに無い (= 未設定) 場合は空文字列が注入され、
`AppConfig.isConfigured == false` となり Mock にフォールバックする。
ローカル開発でも fatalError しないよう設計済み。

### 4.3 動作確認

```bash
make build
```

成功したら、Xcode から iPad シミュレータで起動し:

1. ホーム画面に「サインイン」フルスクリーンが出ること (`isAuthRequired=true`)
2. メールアドレス/パスワードで新規登録 → Supabase Dashboard → Authentication → Users にユーザが現れる
3. サインアウト → ホームへ戻る
4. Apple Sign in は実機でないとフルには動かない (Sandbox Apple ID を作って実機で確認)

---

## 5. CI / CD (GitHub Actions)

`.github/workflows/ci.yml` に既存の SPM テストワークフローがある。リリース版や TestFlight 用には secrets を渡す必要あり。

### 5.1 GitHub Repository Secrets を登録

GitHub リポ → **Settings → Secrets and variables → Actions → New repository secret** で以下を追加:

| Name | Value |
|---|---|
| `SUPABASE_URL` | 本番 Supabase URL |
| `SUPABASE_ANON_KEY` | 本番 anon key |
| `SENTRY_DSN` | Sentry DSN |
| `APPLE_API_KEY_ID` | App Store Connect API Key の ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API の Issuer |
| `APPLE_API_KEY_BASE64` | API Key (.p8) を base64 化したもの |
| `MATCH_PASSWORD` | (fastlane match 利用時) 証明書管理パスワード |

### 5.2 ワークフローからの参照

```yaml
- name: Inject secrets into Config.local.xcconfig
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
    SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
  run: |
    cat > Config.local.xcconfig <<EOF
    SUPABASE_URL = ${SUPABASE_URL//\/\//\/\$()\/}
    SUPABASE_ANON_KEY = $SUPABASE_ANON_KEY
    SENTRY_DSN = ${SENTRY_DSN//\/\//\/\$()\/}
    EOF
```

> URL の `//` は xcconfig コメント開始扱いされるので `/$()/` に変換する。

---

## 6. TestFlight 配信

### 6.1 App Store Connect にアプリ登録

1. <https://appstoreconnect.apple.com/apps> → **+ → New App**
2. 入力:
   - Platform: iOS
   - Name: `Lumi`
   - Bundle ID: `com.muramoto-co.lumi`
   - SKU: `lumi-ios-001`
3. **Create**

### 6.2 ビルドのアップロード

Xcode から:
1. **Product → Archive** (リリースビルド)
2. **Window → Organizer → Distribute App → App Store Connect → Upload**
3. アップロード完了後、App Store Connect → TestFlight タブ で「Processing」表示
4. 5〜10 分で利用可能になる

### 6.3 TestFlight にテスター追加

- Internal Testing: チームメンバーは即追加
- External Testing: メールアドレス追加 → 招待リンクを送信

---

## 7. App Store 審査の準備 (Phase 2.4 公開時)

| 項目 | 用意するもの |
|---|---|
| プライバシーポリシー | LegalFeature 内 + Web 公開 URL |
| 利用規約 | 同上 |
| アカウント削除機能 | 必須 (Sign in with Apple 利用アプリの要件) |
| Privacy Manifest | `PrivacyInfo.xcprivacy` 作成 |
| App Privacy 詳細 | App Store Connect で何を収集するか宣言 |
| スクリーンショット | iPad 13" 5枚 + 12.9" 5枚 |
| App アイコン | 1024×1024 PNG |
| デモアカウント | 審査者用に用意 (in-memory データでも可) |

---

## 8. トラブルシューティング

### Sign in with Apple がループする
- Service ID の Return URL が `<PROJECT_REF>.supabase.co/auth/v1/callback` になっているか
- Apple OAuth の client secret JWT が有効期限内か (期限切れだと再生成)

### Realtime が届かない
- `supabase/migrations/0004_realtime_publication.sql` が適用済か
- Dashboard → Database → Replication で対象テーブルが publication に入っているか
- RLS で当該ユーザに SELECT 権限があるか (Recorder のみ匿名 anon では参照不可)

### Sentry にイベントが届かない
- `Telemetry.start` が `LumiApp.init()` で呼ばれているか
- `AppConfig.sentryDSN` が空文字でないか (空ならスキップされる)
- Debug ビルドの場合、Sentry SDK の `debug = true` を一時設定して確認

### 同期が動かない
- `SupabaseClientProvider.shared` が `nil` だと `MockSyncEngine` にフォールバックする (Config 未設定の合図)
- `AppConfig.isConfigured` が `true` を返すか確認
- ネットワークが繋がっているか (`LiveNetworkMonitor` が `false` を返すと `BufferedSyncEngine.flush()` でも push されない)

---

## 9. チェックリスト

セットアップ完了の確認:

- [ ] `make test` 緑
- [ ] `make build` 成功
- [ ] iPad Pro 13" シミュレータで起動 → サインイン画面が出る
- [ ] メール認証で新規登録 → Supabase Users に出現
- [ ] サインアウト → 再ログイン
- [ ] チーム作成 → 試合作成 → 1ラリー入力 → KPI が表示される
- [ ] Supabase Dashboard → Tables で plays / rallies が増えている (= 同期成功)
- [ ] Sentry Dashboard で test event が届く (`SentrySDK.capture(message:)` で確認)
- [ ] GitHub Actions の CI が緑 (secrets 追加後)
- [ ] `make secrets-scan` がパス
- [ ] `git status` で `Config.local.xcconfig` が untracked であることを確認 (.gitignore 効いてる)
