-- Lumi: インデックス
-- docs/06_DATA_SYNC.md 4.1

CREATE INDEX idx_matches_team_id ON matches(team_id);
CREATE INDEX idx_matches_match_code ON matches(match_code);
CREATE INDEX idx_matches_recorder_id ON matches(recorder_id);
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_sets_match_id ON sets(match_id);
CREATE INDEX idx_rallies_set_id ON rallies(set_id);
CREATE INDEX idx_plays_rally_id ON plays(rally_id);
CREATE INDEX idx_plays_player_id ON plays(player_id) WHERE player_id IS NOT NULL;
CREATE INDEX idx_timeouts_set_id ON timeouts(set_id);
CREATE INDEX idx_substitutions_set_id ON substitutions(set_id);
CREATE INDEX idx_match_members_match_id ON match_members(match_id);
CREATE INDEX idx_service_orders_match_id ON service_orders(match_id);
