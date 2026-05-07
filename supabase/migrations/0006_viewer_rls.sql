-- Lumi: Viewer 用 RLS ポリシー追加
-- viewer_match_id が JWT に含まれている場合、特定試合のみ読み取り可

-- matches: 試合コード経由の Viewer
CREATE POLICY matches_viewer ON matches
  FOR SELECT USING (
    id::text = (auth.jwt() ->> 'viewer_match_id')
  );

-- sets / rallies / plays / timeouts / substitutions も viewer に公開
CREATE POLICY sets_viewer ON sets
  FOR SELECT USING (
    match_id::text = (auth.jwt() ->> 'viewer_match_id')
  );

CREATE POLICY rallies_viewer ON rallies
  FOR SELECT USING (
    set_id IN (
      SELECT id FROM sets WHERE match_id::text = (auth.jwt() ->> 'viewer_match_id')
    )
  );

CREATE POLICY plays_viewer ON plays
  FOR SELECT USING (
    rally_id IN (
      SELECT r.id FROM rallies r
      JOIN sets s ON r.set_id = s.id
      WHERE s.match_id::text = (auth.jwt() ->> 'viewer_match_id')
    )
  );

CREATE POLICY timeouts_viewer ON timeouts
  FOR SELECT USING (
    set_id IN (
      SELECT id FROM sets WHERE match_id::text = (auth.jwt() ->> 'viewer_match_id')
    )
  );

CREATE POLICY substitutions_viewer ON substitutions
  FOR SELECT USING (
    set_id IN (
      SELECT id FROM sets WHERE match_id::text = (auth.jwt() ->> 'viewer_match_id')
    )
  );
