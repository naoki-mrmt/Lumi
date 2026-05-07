-- Lumi: RPC functions
-- 試合コード検証 / Recorder claim / 一意コード生成 / 対戦相手集計

-- ────────────────────────────────────────────────────────────
-- generate_unique_match_code: 32文字 charset から 6桁、重複チェック付き
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_unique_match_code()
RETURNS VARCHAR(6)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  charset TEXT := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  candidate VARCHAR(6);
  attempt INT := 0;
BEGIN
  LOOP
    candidate := '';
    FOR i IN 1..6 LOOP
      candidate := candidate || substr(charset, floor(random() * length(charset) + 1)::int, 1);
    END LOOP;

    -- 既存コードと衝突しなければ返す
    IF NOT EXISTS (SELECT 1 FROM matches WHERE match_code = candidate) THEN
      RETURN candidate;
    END IF;

    attempt := attempt + 1;
    IF attempt >= 100 THEN
      RAISE EXCEPTION 'Failed to generate unique match code after 100 attempts';
    END IF;
  END LOOP;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- validate_match_code: Viewer 参加用にコードを検証
--   - コードが存在し、有効期限内、status != 'abandoned' なら matchId を返す
--   - そうでなければ NULL
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION validate_match_code(p_code VARCHAR(6))
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  result_id UUID;
BEGIN
  SELECT id INTO result_id
    FROM matches
   WHERE match_code = p_code
     AND match_code_expires_at > now()
     AND status <> 'abandoned'
   LIMIT 1;
  RETURN result_id;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- claim_recorder: 自端末を Recorder として登録
--   - matches.recorder_id = auth.uid() (= 自分の試合)
--   - current_recorder_device_id が NULL または 自端末の deviceId なら更新成功
--   - そうでなければ何もしない (NULL を返す)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION claim_recorder(p_match_id UUID, p_device_id TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  claimed_id UUID;
BEGIN
  UPDATE matches
     SET current_recorder_device_id = p_device_id,
         updated_at = now()
   WHERE id = p_match_id
     AND recorder_id = auth.uid()
     AND (current_recorder_device_id IS NULL OR current_recorder_device_id = p_device_id)
  RETURNING id INTO claimed_id;
  RETURN claimed_id;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- release_recorder: 端末がアプリを閉じたとき claim を解放
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION release_recorder(p_match_id UUID, p_device_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE matches
     SET current_recorder_device_id = NULL,
         updated_at = now()
   WHERE id = p_match_id
     AND recorder_id = auth.uid()
     AND current_recorder_device_id = p_device_id;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- opponent_attack_course_aggregate: 過去の対戦相手アタックコース集計
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION opponent_attack_course_aggregate(p_opponent_name TEXT)
RETURNS TABLE(course TEXT, count BIGINT)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT p.attack_course AS course, count(*) AS count
    FROM plays p
    JOIN rallies r ON p.rally_id = r.id
    JOIN sets s    ON r.set_id   = s.id
    JOIN matches m ON s.match_id = m.id
   WHERE m.recorder_id = auth.uid()
     AND m.opponent_team_name = p_opponent_name
     AND p.play_team = 'opponent'
     AND p.play_type = 'attack'
     AND p.attack_course IS NOT NULL
   GROUP BY p.attack_course;
$$;

-- ────────────────────────────────────────────────────────────
-- opponent_serve_course_aggregate: 過去の対戦相手サーブゾーン集計
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION opponent_serve_course_aggregate(p_opponent_name TEXT)
RETURNS TABLE(zone INT, count BIGINT)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT p.serve_course AS zone, count(*) AS count
    FROM plays p
    JOIN rallies r ON p.rally_id = r.id
    JOIN sets s    ON r.set_id   = s.id
    JOIN matches m ON s.match_id = m.id
   WHERE m.recorder_id = auth.uid()
     AND m.opponent_team_name = p_opponent_name
     AND p.play_team = 'opponent'
     AND p.play_type = 'serve'
     AND p.serve_course IS NOT NULL
   GROUP BY p.serve_course;
$$;

-- ────────────────────────────────────────────────────────────
-- viewer_session: 試合コード経由で Viewer の JWT クレームに matchId を埋める
--   - Phase 2 で本番運用時に使用 (RLS で auth.jwt() ->> 'viewer_match_id' を参照)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION viewer_session(p_code VARCHAR(6))
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  match_uuid UUID;
BEGIN
  match_uuid := validate_match_code(p_code);
  IF match_uuid IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired match code';
  END IF;
  -- 実装メモ: Supabase Edge Function で JWT を発行し、claims に viewer_match_id を入れる
  --   その JWT で接続した Viewer は plays/rallies テーブルを限定的に読める
  RETURN match_uuid;
END;
$$;

-- 権限付与 (anon でも viewer_session / validate_match_code を呼べるように)
GRANT EXECUTE ON FUNCTION validate_match_code(VARCHAR) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION viewer_session(VARCHAR) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION generate_unique_match_code() TO authenticated;
GRANT EXECUTE ON FUNCTION claim_recorder(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION release_recorder(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION opponent_attack_course_aggregate(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION opponent_serve_course_aggregate(TEXT) TO authenticated;
