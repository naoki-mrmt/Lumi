-- Lumi: Realtime 設定
-- docs/06_DATA_SYNC.md 4.3

ALTER PUBLICATION supabase_realtime ADD TABLE matches;
ALTER PUBLICATION supabase_realtime ADD TABLE sets;
ALTER PUBLICATION supabase_realtime ADD TABLE rallies;
ALTER PUBLICATION supabase_realtime ADD TABLE plays;
ALTER PUBLICATION supabase_realtime ADD TABLE timeouts;
ALTER PUBLICATION supabase_realtime ADD TABLE substitutions;
