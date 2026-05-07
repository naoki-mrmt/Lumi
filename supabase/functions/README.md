# Supabase Edge Functions

## 関数一覧

| 関数 | 用途 | トリガ |
|---|---|---|
| `viewer-session` | 試合コードから Viewer JWT 発行 | iOS App から HTTPS POST |
| `cleanup-expired-codes` | 期限切れコードを abandoned 化 | pg_cron で 1日1回 |

## デプロイ

```bash
supabase login
supabase link --project-ref <YOUR_REF>

# 環境変数を設定
supabase secrets set LUMI_VIEWER_JWT_SECRET="$(openssl rand -hex 32)"
supabase secrets set CRON_SECRET="$(openssl rand -hex 32)"

# 関数デプロイ
supabase functions deploy viewer-session
supabase functions deploy cleanup-expired-codes --no-verify-jwt
```

## pg_cron 設定 (cleanup-expired-codes)

Dashboard > Database > Cron Jobs で以下を追加:

```sql
SELECT cron.schedule(
  'cleanup-expired-codes',
  '0 3 * * *',  -- 毎日 03:00 UTC
  $$
    SELECT net.http_post(
      url := 'https://<YOUR_REF>.functions.supabase.co/cleanup-expired-codes',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.cron_secret'),
        'Content-Type', 'application/json'
      )
    );
  $$
);
```

## ローカル開発

```bash
supabase functions serve viewer-session
curl -X POST http://localhost:54321/functions/v1/viewer-session \
  -H 'Content-Type: application/json' \
  -d '{"code":"ABCDEF"}'
```
