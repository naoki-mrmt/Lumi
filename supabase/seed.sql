-- Lumi: ローカル開発用 seed データ
-- supabase start 時に自動実行される。本番には適用しない。

-- テスト用ユーザーは Supabase Dashboard から作成するか、auth.users を直接 INSERT
-- 例:
-- INSERT INTO auth.users (id, email) VALUES ('00000000-0000-0000-0000-000000000001', 'test@example.com')
--   ON CONFLICT DO NOTHING;
-- INSERT INTO profiles (id, display_name) VALUES ('00000000-0000-0000-0000-000000000001', 'テストユーザー')
--   ON CONFLICT DO NOTHING;
