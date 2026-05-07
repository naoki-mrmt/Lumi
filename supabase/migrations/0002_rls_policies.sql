-- Lumi: Row Level Security
-- docs/06_DATA_SYNC.md 4.2

-- profiles: 自分のみ
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY profiles_self ON profiles
  FOR ALL USING (auth.uid() = id);

-- teams: owner のみ
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY teams_owner ON teams
  FOR ALL USING (auth.uid() = owner_id);

-- players: 親 team の owner
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
CREATE POLICY players_via_team ON players
  FOR ALL USING (
    team_id IN (SELECT id FROM teams WHERE owner_id = auth.uid())
  );

-- match_members
ALTER TABLE match_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY match_members_via_match ON match_members
  FOR ALL USING (
    match_id IN (SELECT id FROM matches WHERE recorder_id = auth.uid())
  );

-- service_orders
ALTER TABLE service_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY service_orders_via_match ON service_orders
  FOR ALL USING (
    match_id IN (SELECT id FROM matches WHERE recorder_id = auth.uid())
  );

-- sets
ALTER TABLE sets ENABLE ROW LEVEL SECURITY;
CREATE POLICY sets_via_match ON sets
  FOR ALL USING (
    match_id IN (SELECT id FROM matches WHERE recorder_id = auth.uid())
  );

-- substitutions
ALTER TABLE substitutions ENABLE ROW LEVEL SECURITY;
CREATE POLICY substitutions_via_set ON substitutions
  FOR ALL USING (
    set_id IN (
      SELECT s.id FROM sets s
      JOIN matches m ON s.match_id = m.id
      WHERE m.recorder_id = auth.uid()
    )
  );

-- timeouts
ALTER TABLE timeouts ENABLE ROW LEVEL SECURITY;
CREATE POLICY timeouts_via_set ON timeouts
  FOR ALL USING (
    set_id IN (
      SELECT s.id FROM sets s
      JOIN matches m ON s.match_id = m.id
      WHERE m.recorder_id = auth.uid()
    )
  );

-- rallies
ALTER TABLE rallies ENABLE ROW LEVEL SECURITY;
CREATE POLICY rallies_via_set ON rallies
  FOR ALL USING (
    set_id IN (
      SELECT s.id FROM sets s
      JOIN matches m ON s.match_id = m.id
      WHERE m.recorder_id = auth.uid()
    )
  );

-- plays
ALTER TABLE plays ENABLE ROW LEVEL SECURITY;
CREATE POLICY plays_via_rally ON plays
  FOR ALL USING (
    rally_id IN (
      SELECT r.id FROM rallies r
      JOIN sets s ON r.set_id = s.id
      JOIN matches m ON s.match_id = m.id
      WHERE m.recorder_id = auth.uid()
    )
  );

-- matches: Recorder ポリシー (Viewer は別途 RPC で発行された JWT 経由想定)
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
CREATE POLICY matches_recorder ON matches
  FOR ALL USING (recorder_id = auth.uid());
