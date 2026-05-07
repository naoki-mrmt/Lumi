-- Lumi: 初期スキーマ
-- docs/06_DATA_SYNC.md 4.1 から転記

-- ユーザー (Supabase Auth で自動管理されるが、プロフィール拡張用)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- チーム
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES profiles(id),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 選手 (最大15人/チーム)
CREATE TABLE players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  jersey_number INTEGER NOT NULL,
  name TEXT NOT NULL,
  position_tendency TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (team_id, jersey_number)
);

-- 試合
CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id),
  recorder_id UUID NOT NULL REFERENCES profiles(id),
  match_code VARCHAR(6) UNIQUE NOT NULL,
  match_code_expires_at TIMESTAMPTZ NOT NULL,
  match_date DATE NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  opponent_team_name TEXT NOT NULL,
  tournament_name TEXT,
  match_type TEXT NOT NULL DEFAULT 'official',
  venue TEXT,
  status TEXT NOT NULL DEFAULT 'preparing',
  current_recorder_device_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 試合メンバー
CREATE TABLE match_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES players(id),
  is_starter BOOLEAN NOT NULL,
  UNIQUE (match_id, player_id)
);

-- サービス順
CREATE TABLE service_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  order_number INTEGER NOT NULL,
  starting_player_id UUID NOT NULL REFERENCES players(id),
  current_player_id UUID NOT NULL REFERENCES players(id),
  UNIQUE (match_id, order_number)
);

-- セット
CREATE TABLE sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  set_number INTEGER NOT NULL,
  formation TEXT NOT NULL DEFAULT '5-1-3',
  custom_formation TEXT,
  our_score_final INTEGER,
  opponent_score_final INTEGER,
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ,
  UNIQUE (match_id, set_number)
);

-- 選手交代
CREATE TABLE substitutions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  set_id UUID NOT NULL REFERENCES sets(id) ON DELETE CASCADE,
  our_score INTEGER NOT NULL,
  opponent_score INTEGER NOT NULL,
  player_in_id UUID NOT NULL REFERENCES players(id),
  player_out_id UUID NOT NULL REFERENCES players(id),
  service_order_id UUID NOT NULL REFERENCES service_orders(id),
  substitution_count_in_set INTEGER NOT NULL CHECK (substitution_count_in_set BETWEEN 1 AND 4),
  timestamp TIMESTAMPTZ DEFAULT now()
);

-- タイムアウト
CREATE TABLE timeouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  set_id UUID NOT NULL REFERENCES sets(id) ON DELETE CASCADE,
  our_score INTEGER NOT NULL,
  opponent_score INTEGER NOT NULL,
  requesting_team TEXT NOT NULL CHECK (requesting_team IN ('own', 'opponent')),
  timeout_type TEXT NOT NULL DEFAULT 'regular',
  timestamp TIMESTAMPTZ DEFAULT now()
);

-- ラリー
CREATE TABLE rallies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  set_id UUID NOT NULL REFERENCES sets(id) ON DELETE CASCADE,
  rally_number INTEGER NOT NULL,
  start_score_us INTEGER NOT NULL,
  start_score_opp INTEGER NOT NULL,
  serving_team TEXT NOT NULL CHECK (serving_team IN ('own', 'opponent')),
  serving_player_id UUID REFERENCES players(id),
  opponent_serving_jersey INTEGER,
  winner TEXT CHECK (winner IN ('own', 'opponent')),
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ
);

-- プレー
CREATE TABLE plays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rally_id UUID NOT NULL REFERENCES rallies(id) ON DELETE CASCADE,
  sequence_in_rally INTEGER NOT NULL,
  play_team TEXT NOT NULL CHECK (play_team IN ('own', 'opponent')),
  player_id UUID REFERENCES players(id),
  opponent_jersey INTEGER,
  play_type TEXT NOT NULL CHECK (play_type IN ('serve', 'reception', 'set', 'attack', 'block', 'dig', 'error')),
  evaluation TEXT NOT NULL CHECK (evaluation IN ('excellent', 'good', 'normal', 'error')),
  serve_type TEXT CHECK (serve_type IN ('float', 'jump', 'jump_float')),
  serve_attempt TEXT CHECK (serve_attempt IN ('first', 'second')),
  reception_quality TEXT CHECK (reception_quality IN ('a_pass', 'b_pass', 'c_pass', 'd_pass')),
  attack_course TEXT CHECK (attack_course IN ('cross', 'straight', 'inner', 'feint', 'other')),
  serve_course INTEGER CHECK (serve_course BETWEEN 1 AND 9),
  block_count INTEGER CHECK (block_count BETWEEN 1 AND 3),
  error_type TEXT,
  timestamp TIMESTAMPTZ DEFAULT now(),
  video_offset_seconds REAL,
  is_assist BOOLEAN DEFAULT false
);
