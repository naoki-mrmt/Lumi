# 06. Data Sync — データ同期戦略

## 1. 基本方針

### 1.1 データの真実の源（Source of Truth）

**正本 = Supabase（クラウド）**
- すべての試合データの正本はクラウド
- 入力iPad（Recorder）から1プレーごとに非同期push
- 閲覧iPad（Viewer）はクラウドからリアルタイム購読

**ローカル = 送信失敗時のバッファ**
- ネット切断・タイムアウト等でクラウドへの送信が失敗したプレーを一時保持
- 復帰時に自動でクラウドへ送信
- 送信成功したらローカルバッファからは削除（または「送信済み」マーク）

### 1.2 ロール分離

| ロール | 権限 | 端末数 | アカウント |
|---|---|---|---|
| **Recorder** | 入力・編集・試合管理 | **1試合1端末** | 必須（Sign in with Apple） |
| **Viewer** | 閲覧のみ（読み取り専用） | 複数台OK | 不要（試合コードのみ） |

## 2. データフロー

### 2.1 Recorder側のフロー

```
[Recorder iPad]
  └→ プレー入力
      └→ ① ローカルバッファに即時保存（SwiftData）
      └→ ② Supabase へ非同期push（並列）
          ├ 成功 → ローカルバッファから削除
          └ 失敗 → ローカルバッファに保留
              └→ ネット復帰時に再送（指数バックオフ）

  並行：10秒ごとに State スナップショット保存（クラッシュ復元用）
```

### 2.2 Viewer側のフロー

```
[Supabase Realtime]
  └→ 各テーブル変更を監視
      └→ Viewer iPad へPush

[Viewer iPad]
  └→ Realtime Listener で購読
      └→ 受信データを State に反映
      └→ KPI 自動再計算 → UI更新

  ※ローカルキャッシュは Supabase SDK 任せ（明示管理しない）
```

### 2.3 オフライン時の動作

#### Recorder
- ✅ プレー入力可能（ローカルバッファに溜まる）
- ✅ KPI 計算可能（ローカルデータのみで完結）
- ✅ 試合進行可能（完全自律）
- ⚠️ 上部に同期ステータス表示（赤バッジ「未同期 N件」）
- 🔄 ネット復帰時：自動的に蓄積分をバッチ送信

#### Viewer
- ⚠️ オフライン時は最終受信データを表示
- ⚠️ 「Recorderと未接続」バナー表示
- 🔄 ネット復帰時：自動的に最新データを取得

### 2.4 完全オフライン運用シナリオ

体育館でずっとネット繋がらない場合：
- **Recorder は試合を完遂可能**（オフラインで全機能動作）
- **Viewer は何も見えない**（Recorderと通信できないため）
- 試合終了後、Recorderがネット環境に戻ったタイミングで一括同期
- 一括同期完了後、Viewerでも閲覧可能になる

## 3. 試合コードによる Viewer 参加フロー

### 3.1 試合コードの仕様

- **6桁の英数字**（紛らわしい文字を除外：0/O, 1/I/l）
- 試合作成時に自動発行
- 試合終了から **24時間で失効**（セキュリティ）
- 一意性は保証（重複時は再生成）

### 3.2 参加フロー

```
[Recorder]
  1. 試合作成
  2. Supabase に Match レコード作成（match_code 含む）
  3. UI に試合コード表示（共有しやすいよう大きく）

[Viewer]
  4. アプリ起動
  5. 「試合コード入力」画面で 6桁入力
  6. Supabase に問い合わせ：
     - コードが有効か（期限切れチェック）
     - 試合が存在するか
  7. 該当 Match に Realtime 購読開始
  8. リアルタイム閲覧開始
```

### 3.3 Recorder衝突防止

- 試合作成時にRecorder端末（Auth uid）が Match.recorder_id に登録される
- 別端末で同じ試合を開いた時：
  - その端末のAuth uid が Match.recorder_id と一致 → Recorderモード
  - 一致しない → 自動的に Viewer モード（強制）
- 「Recorder引き継ぎ」操作（明示的）でRecorder変更可能

## 4. Supabase スキーマ詳細

### 4.1 テーブル定義（PostgreSQL）

```sql
-- ユーザー（Supabase Auth で自動管理されるが、プロフィール拡張用）
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

-- 選手（最大15人/チーム）
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
  match_type TEXT NOT NULL DEFAULT 'official', -- official/practice/training_camp
  venue TEXT,
  status TEXT NOT NULL DEFAULT 'preparing', -- preparing/in_progress/finished/abandoned
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

-- インデックス
CREATE INDEX idx_matches_team_id ON matches(team_id);
CREATE INDEX idx_matches_match_code ON matches(match_code);
CREATE INDEX idx_sets_match_id ON sets(match_id);
CREATE INDEX idx_rallies_set_id ON rallies(set_id);
CREATE INDEX idx_plays_rally_id ON plays(rally_id);
CREATE INDEX idx_plays_player_id ON plays(player_id) WHERE player_id IS NOT NULL;
```

### 4.2 Row Level Security (RLS)

```sql
-- profiles: 自分のプロファイルのみ読み書き
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY profiles_self ON profiles
  FOR ALL USING (auth.uid() = id);

-- teams: 自分が所有するチームのみ
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY teams_owner ON teams
  FOR ALL USING (auth.uid() = owner_id);

-- players, match_members, service_orders, sets, substitutions, timeouts, rallies, plays:
-- 親 team の owner のみ
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
CREATE POLICY players_via_team ON players
  FOR ALL USING (
    team_id IN (SELECT id FROM teams WHERE owner_id = auth.uid())
  );

-- matches: Recorder（owner）またはViewer（試合コード経由）
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

-- Recorder用ポリシー
CREATE POLICY matches_recorder ON matches
  FOR ALL USING (recorder_id = auth.uid());

-- Viewer用ポリシー（試合コード経由・読み取り専用）
-- ※試合コードは別途 RPC 関数で検証する想定
```

### 4.3 Realtime購読の設定

```sql
-- 主要テーブルに Realtime を有効化
ALTER PUBLICATION supabase_realtime ADD TABLE matches;
ALTER PUBLICATION supabase_realtime ADD TABLE sets;
ALTER PUBLICATION supabase_realtime ADD TABLE rallies;
ALTER PUBLICATION supabase_realtime ADD TABLE plays;
ALTER PUBLICATION supabase_realtime ADD TABLE timeouts;
ALTER PUBLICATION supabase_realtime ADD TABLE substitutions;
```

## 5. Swift側の実装方針

### 5.1 Supabase Client初期化

```swift
import Supabase

extension SupabaseClient {
  static let shared = SupabaseClient(
    supabaseURL: URL(string: AppConfig.supabaseURL)!,
    supabaseKey: AppConfig.supabaseAnonKey
  )
}
```

### 5.2 同期エンジンのインターフェース

```swift
protocol SyncEngine {
  /// プレーをクラウドに送信。失敗時はローカルバッファに保持。
  func push(_ play: Play) async throws
  
  /// バッファ内の未送信データを再送
  func flush() async throws
  
  /// 試合のリアルタイム購読を開始
  func subscribe(to matchId: UUID) -> AsyncStream<MatchUpdate>
  
  /// 購読を解除
  func unsubscribe()
}
```

### 5.3 オフライン検知

```swift
import Network

@Observable
class NetworkMonitor {
  private(set) var isOnline: Bool = true
  private let monitor = NWPathMonitor()
  
  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in
        self?.isOnline = path.status == .satisfied
      }
    }
    monitor.start(queue: .global())
  }
}
```

## 6. クラッシュリカバリ

### 6.1 State スナップショット

試合中、Recorder は10秒ごとに現在の State を SwiftData に保存：

```swift
// 概念図
@Reducer
struct MatchInputFeature {
  // ...
  
  Reduce { state, action in
    switch action {
    // ...
    }
  }
  ._printChanges()
  
  // 副作用：定期保存
  Effect.run { send in
    for await _ in Timer.publish(every: 10, on: .main, in: .default).autoconnect().values {
      await send(.snapshotRequested)
    }
  }
}
```

### 6.2 起動時の復元

アプリ起動時：
1. SwiftData に「未完了の試合」があるかチェック（status = 'in_progress'）
2. あれば「中断中の試合を復元しますか？」ダイアログ表示
3. ユーザー選択：復元 / 破棄

## 7. 同期の信頼性

### 7.1 Idempotency（冪等性）

すべての送信は `play.id` で一意性を保証。同じプレーを2回送っても重複しない（ON CONFLICT DO NOTHING または UPSERT）。

### 7.2 順序保証

- ラリー内の Play は `sequence_in_rally` で順序を保持
- 受信側は順序を意識して再構成

### 7.3 エラー時のリトライ

- 指数バックオフ（1秒 → 2秒 → 4秒 → 8秒、最大60秒）
- 5回失敗したら通知バナー表示・手動リトライボタン

## 8. パフォーマンス考慮

### 8.1 Recorder側

- プレー入力 → State更新は同期的・即座（100ms以内）
- Supabase送信は非同期・バックグラウンド
- UI更新を絶対にブロックしない

### 8.2 Viewer側

- Realtime メッセージ受信 → State更新 → UI再描画
- 大量メッセージ対策：deboucing（100ms以内のメッセージは集約）
- KPI計算はメインスレッドを避ける

## 9. テスト戦略

詳細は `08_NON_FUNCTIONAL.md` 参照。

- 同期エンジンのモック：`SyncEngine` の `liveValue` / `testValue` を切り替え
- オフライン挙動テスト：NetworkMonitor をモック化
- データ整合性テスト：プレー入力 → DB状態を検証

## 10. データバックアップとエクスポート

### 10.1 自動バックアップ

- Recorder：試合終了時にローカルにJSON形式で全データ保存（Filesアプリで参照可）
- 試合削除時：削除前にもJSONバックアップ生成

### 10.2 ユーザーによるエクスポート

- 試合データ全体をJSON形式でエクスポート
- 共有シート経由で iCloud Drive 等に保存
