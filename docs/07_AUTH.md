# 07. Authentication — 認証と試合コード設計

## 1. 認証戦略の概要

### 1.1 ロール別の認証要件

| ロール | アカウント | 認証方法 | 端末数 |
|---|---|---|---|
| **Recorder** | 必須 | Sign in with Apple（Phase 1） / メール認証（Phase 2追加） | 同一アカウントで複数端末ログイン可、ただし試合のRecorderは1端末 |
| **Viewer** | 不要 | 試合コード（6桁）のみ | 複数台OK |

### 1.2 設計原則

- **Recorderには本人特定が必要**（データ所有者として、データ保持・復旧のため）
- **Viewerには認証コストをかけない**（ベンチに渡すiPadに毎回ログインさせるのはUX最悪）
- **試合コード自体が試合限定の入場券として機能**（24時間有効）

## 2. Recorder認証：Sign in with Apple

### 2.1 採用理由

- iPad ユーザーは Apple ID を持っている前提（iPad使用にApple ID必須のため）
- パスワード管理不要、UX最高
- App Store 審査でも要求される標準
- Apple のプライバシー保護機能（Hide My Email）対応

### 2.2 実装方針

#### Sign in with Apple ボタン

```swift
import AuthenticationServices

SignInWithAppleButton(
  onRequest: { request in
    request.requestedScopes = [.fullName, .email]
  },
  onCompletion: { result in
    Task {
      await handleSignIn(result: result)
    }
  }
)
.signInWithAppleButtonStyle(.white)
.frame(height: 50)
```

#### Supabase Auth との連携

```swift
import Supabase

func signInWithApple(idToken: String, nonce: String) async throws {
  try await SupabaseClient.shared.auth.signInWithIdToken(
    credentials: .init(
      provider: .apple,
      idToken: idToken,
      nonce: nonce
    )
  )
}
```

#### nonce生成（セキュリティ）

```swift
private func randomNonce(length: Int = 32) -> String {
  let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
  return String((0..<length).map { _ in charset.randomElement()! })
}

private func sha256(_ input: String) -> String {
  let inputData = Data(input.utf8)
  let hashed = SHA256.hash(data: inputData)
  return hashed.compactMap { String(format: "%02x", $0) }.joined()
}
```

### 2.3 Supabaseでの設定

Supabase Dashboard で：
1. Authentication > Providers > Apple を有効化
2. Apple Developer のService IDを設定
3. Apple Developer Console で Sign in with Apple を有効化（既に加入済み）
4. Domain・Return URL を Supabase のドメインに設定

### 2.4 セッション管理

- アクセストークンは Supabase SDK が自動管理
- 自動リフレッシュ
- Keychain に保存（SDK が処理）

### 2.5 ログアウト

```swift
func signOut() async throws {
  try await SupabaseClient.shared.auth.signOut()
}
```

## 3. メール認証（Phase 2.4追加）

### 3.1 採用理由

- Apple ID を持っていないユーザー対応
- 公開展開時のフォールバック手段
- パスワードリセットフローもSupabase Authが標準提供

### 3.2 実装

Phase 2.4 で追加。Supabase Auth の標準機能を使用：

```swift
// サインアップ
try await SupabaseClient.shared.auth.signUp(
  email: email,
  password: password
)

// ログイン
try await SupabaseClient.shared.auth.signIn(
  email: email,
  password: password
)
```

## 4. 試合コード方式（Viewer参加）

### 4.1 試合コードの仕様

- **6桁の英数字**
- **紛らわしい文字を除外**：`0`/`O`、`1`/`I`/`l` 
- **使用文字セット**：`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`（32文字）
- **総組み合わせ**：32^6 ≒ 10億通り（衝突可能性は実用上ゼロ）

### 4.2 試合コード生成ロジック

```swift
struct MatchCodeGenerator {
  private static let charset: [Character] = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
  
  static func generate() -> String {
    String((0..<6).map { _ in charset.randomElement()! })
  }
}
```

### 4.3 試合コード検証フロー

Viewer が試合コードを入力した時：

```swift
func validateMatchCode(_ code: String) async throws -> Match {
  let response = try await SupabaseClient.shared
    .from("matches")
    .select()
    .eq("match_code", value: code)
    .gte("match_code_expires_at", value: Date())
    .single()
    .execute()
  
  guard let match = try? response.value as? Match else {
    throw AuthError.invalidMatchCode
  }
  
  return match
}
```

### 4.4 試合コードの有効期限

- 試合作成時：`match_code_expires_at = match_date + 24h`
- 試合終了後でも24時間は閲覧可能
- 期限切れ後はエラー表示「この試合は終了から24時間が経過しました」

### 4.5 試合コードを使ったRLS

Supabase の Row Level Security 設計：

```sql
-- Viewerは試合コードを知っている場合のみ、その試合の関連データを読み取り可能
-- ※実装は RPC 関数経由で行う（パスワードレス入場）

CREATE OR REPLACE FUNCTION get_match_by_code(p_code TEXT)
RETURNS SETOF matches
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT * FROM matches
  WHERE match_code = p_code
    AND match_code_expires_at > now();
$$;

-- Viewerクライアントから RPC で呼び出し
-- 該当 match の関連データ（sets, rallies, plays等）を一括取得
-- 以降は Realtime で購読
```

### 4.6 不正アクセス防止

- 試合コードのレートリミット：1分間に5回失敗で15分ロック
- ブルートフォース防御：32^6 = 10億通りなので実用上不可能だが、念のため

## 5. Recorder引き継ぎ

### 5.1 シナリオ

- 元のRecorder iPadが故障した
- 別のスタッフが入力を引き継ぐ
- 同じアカウントの別端末で試合を開きたい

### 5.2 引き継ぎフロー

```
[元Recorder]                  [新Recorder（同アカウント）]
                                  │
                                  ├ 試合一覧から該当試合を開く
                                  │
                                  ├ システムが警告：
                                  │   「他の端末でRecorderが動作中。
                                  │    引き継ぎますか？」
                                  │
                                  ├ ユーザーが「引き継ぎ」を選択
                                  │
                                  ├ Supabase に新端末IDを登録
                                  │
[元Recorder] ←── 通知 ──── 元の端末はViewerモードに自動移行
```

### 5.3 実装

`matches` テーブルに `current_recorder_device_id` を追加：

```sql
ALTER TABLE matches ADD COLUMN current_recorder_device_id TEXT;
```

各端末はインストール時に一意のデバイスIDを生成（`UIDevice.identifierForVendor`）して保存。Recorderになる時に `current_recorder_device_id` を更新。他端末はこの値を見て自分がRecorderか判定。

## 6. アカウント削除（GDPR対応）

### 6.1 ユーザーがアカウント削除要求

Phase 2.4で実装：

1. アプリ内に「アカウント削除」メニュー
2. 削除前に警告：「全データが消えます」
3. 削除実行：
   - profiles レコード削除（CASCADE で関連データすべて削除）
   - Supabase Auth からも削除
   - ローカルデータも消去

### 6.2 Apple側の要件

App Store ガイドラインで「アプリ内でのアカウント削除機能」が必須（Sign in with Apple使用時）。

## 7. 子供のプライバシー保護

### 7.1 13歳未満ユーザーへの対応

ママさんバレー想定で「ジュニアバレー」連動の可能性も：
- Phase 2.4公開時にApp Store審査で対応
- 必要に応じて「13歳以上のみ利用可能」の制約を付ける

## 8. セキュリティ・チェックリスト

| 項目 | Phase 1.0 | Phase 2.4 |
|---|---|---|
| HTTPS強制 | ✅ Supabase標準 | ✅ |
| トークンKeychain保管 | ✅ SDK標準 | ✅ |
| nonce検証（Sign in with Apple） | ✅ 必須 | ✅ |
| RLS（Row Level Security） | ✅ | ✅ |
| 試合コードレートリミット | ✅ | ✅ |
| パスワード認証 | ❌ | ✅ Phase 2.4で追加 |
| 2要素認証 | ❌ | ⚠️ 検討 |
| アカウント削除機能 | ❌（個人開発、自己責任） | ✅ App Store要件 |
| プライバシーポリシー | ❌ | ✅ App Store要件 |
| 利用規約 | ❌ | ✅ App Store要件 |

## 9. 実装上の注意

### 9.1 開発時のテストアカウント

- Supabase ダッシュボードで開発用テストアカウント作成
- Apple Developer の Sandbox Apple ID を使用
- 本番データと混在しないよう環境分離

### 9.2 Supabase Auth のローカルテスト

- Supabase CLI でローカル Supabase 起動
- ローカル環境では magic link 認証で簡易テスト
- Sign in with Apple のテストは Sandbox 環境で

### 9.3 エラーハンドリング

| エラー | UX |
|---|---|
| Sign in with Apple キャンセル | 静かにダイアログを閉じる |
| ネットワークエラー | リトライ可能なメッセージ |
| トークン期限切れ | 自動リフレッシュ、失敗時は再ログイン誘導 |
| アカウント削除済み | ログイン画面に戻り、メッセージ表示 |
| 試合コード無効 | 「コードが間違っているか期限切れです」 |
| 試合コード期限切れ | 「この試合は閲覧期限を過ぎました」 |
