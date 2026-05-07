-- Lumi: アカウント削除時の連鎖削除
--
-- delete-account Edge Function が auth.admin.deleteUser を呼ぶ時、
-- profiles → teams → matches までを CASCADE で連鎖削除させる。
-- 既存マイグレーションでは profiles/teams/matches.recorder_id の FK に
-- ON DELETE 句が無く、auth.users の削除時に FK 違反で失敗する。

-- profiles: auth.users が消えたら profiles も消す
ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_id_fkey,
  ADD  CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- teams.owner_id: profiles が消えたら teams も消す
ALTER TABLE teams
  DROP CONSTRAINT IF EXISTS teams_owner_id_fkey,
  ADD  CONSTRAINT teams_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- matches.team_id: teams が消えたら matches も消す (元々無し → 追加)
ALTER TABLE matches
  DROP CONSTRAINT IF EXISTS matches_team_id_fkey,
  ADD  CONSTRAINT matches_team_id_fkey
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

-- matches.recorder_id: profiles が消えたら matches も消す (元々無し → 追加)
ALTER TABLE matches
  DROP CONSTRAINT IF EXISTS matches_recorder_id_fkey,
  ADD  CONSTRAINT matches_recorder_id_fkey
    FOREIGN KEY (recorder_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- match_members.match_id (元々 CASCADE あり → 確認のみ)
-- service_orders.match_id (元々 CASCADE あり → 確認のみ)
-- match_sets.match_id (元々 CASCADE あり → 確認のみ)
-- rallies.set_id (元々 CASCADE あり → 確認のみ)
-- plays.rally_id (元々 CASCADE あり → 確認のみ)
-- timeouts.set_id (元々 CASCADE あり → 確認のみ)
-- substitutions.set_id (元々 CASCADE あり → 確認のみ)
