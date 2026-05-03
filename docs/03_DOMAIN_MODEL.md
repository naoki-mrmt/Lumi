# 03. Domain Model — 9人制バレーボール ドメイン知識とデータモデル

## 1. 9人制バレーボール ドメイン知識

このドキュメントは設計判断のベースとなる **9人制特有のルール・用語の正確な仕様** をまとめたもの。

### 1.1 9人制の核となる差分（vs 6人制）

| 項目 | 9人制 | 6人制 |
|---|---|---|
| 1チーム人数 | 9人 | 6人 |
| ローテーション | **なし**（フリーポジション） | あり（時計回り） |
| ポジション制限 | なし | バックローはアタックライン制限あり |
| サーブ回数 | **2回**（1stミス可） | 1回 |
| ブロックの接触カウント | **1回にカウント** | カウントしない |
| 1セットの得点 | **21点**（20-20でデュース、2点差） | 25点（24-24でデュース） |
| ネットインサーブ | **失敗扱い** | 有効 |
| ネットプレー | ボールがネットに触れたら同一選手再接触OK（実質4回タッチ可能） | 同一選手再接触不可 |
| オーバーネット | 全面禁止（ブロック含む） | ブロック時は例外あり |

### 1.2 9人制のポジション表記

**位置**（フリーポジションだが、定位置の呼称として使用）：

```
        ネット側
   ┌─────┬─────┬─────┐
   │ FL  │ FC  │ FR  │  Forward（前衛）
   ├─────┼─────┼─────┤
   │ HL  │ HC  │ HR  │  Half（中衛）
   ├─────┼─────┼─────┤
   │ BL  │ BC  │ BR  │  Back（後衛）
   └─────┴─────┴─────┘
        エンドライン側
```

- F = Forward（前衛）
- H = Half（中衛）
- B = Back（後衛）
- L = Left, C = Center, R = Right

### 1.3 主要フォーメーション

| フォーメーション | 配置 | 特徴 | 主な層 |
|---|---|---|---|
| **5-1-3** | 前衛5・ハーフ1・後衛3 | 最ポピュラー、ハーフセン（HC）が要 | 全層特にママさん |
| **6-3** | 前衛/ハーフ6・後衛3 | 守備重視 | ママさん・地域連盟 |
| **4-2-3** | 前衛4・ハーフ2・後衛3 | バランス型 | 中堅 |
| **3-3-3** | 前衛3+ハーフ3+後衛3 | 攻撃型・3枚ブロック前提 | 男子実業団・V9 |

> 「数字 = 守備時のフォーメーション」であり、攻撃の組み立てとは別概念。

### 1.4 サービス順ルール（重要）

1. **試合前にサービス順を提出**（オーダーシート / ラインアップシート）
2. **試合中は順番変更不可**
3. **次セット最初のサーバー** = 前セット最終サーバーの**次の順番**
4. **選手交代時** = 交代した選手は元の選手の**順番を引き継ぐ**
5. **同一選手が連続で打ち続けられる**（得点が続く限り）
6. **再交代制限**：先発選手がベンチに戻った後、同セット内で一度だけ元のサーブ順の選手と再交代可能

### 1.5 選手交代ルール

- **1セットあたり最大4回**まで
- **1回につき最大3人**まで同時交代可能
- 交代した選手は元の選手と同じサービス順を引き継ぐ
- 同一セット内で一度だけ再出場可能（先発選手→交代選手→先発選手の流れ）

### 1.6 タイムアウトルール

- **1セットあたり最大2回**（各チーム）
- **1回30秒**
- **次セットへの持ち越し不可**
- 監督またはゲームキャプテンがハンドシグナルで要求
- ラリー終了後、次のサービス許可吹笛までに要求

### 1.7 9人制で対応しないもの（非対応の明示）

- ❌ **3点連続交代ローカルルール**（ママさんバレーの一部地域大会のみ）
- ❌ **テクニカルタイムアウト**（9人制ではそもそも標準ではない）
- ❌ **チャレンジ制度**（9人制では未採用）

### 1.8 用語集

| 用語 | 意味 |
|---|---|
| **Aパス** | セッターの定位置に正確に返ったレセプション |
| **Bパス** | セッターが少し動いて取れる範囲のレセプション |
| **Cパス** | セッターが大きく動く必要があるレセプション |
| **Dパス** | セッターに返らなかった、攻撃に絡めないレセプション |
| **アタック決定率** | 決定数 / 打数 × 100（%） |
| **アタック効果率** | (決定数 - 失点) / 打数 × 100（%） |
| **サービスエース** | 1本目で得点したサーブ（または相手のレセプションミスを誘発） |
| **ブロックアウト** | アタックが相手ブロックに当たって場外に出る → 自チームの決定 |
| **被ブロック** | アタックがブロックされて自陣に落ちる → 自チームの失点 |
| **アシスト** | 決定打の直前のセット |
| **連続得点** | 同一チームが連続で得点した回数（3点以上でハイライト） |

---

## 2. データモデル（論理設計）

### 2.1 エンティティ関係図（テキスト版）

```
User (Recorderのみ)
 │
 └─ owns ──> Team
              │
              ├─ has ──> Player (1〜15人)
              │
              └─ plays ──> Match
                            │
                            ├─ has ──> MatchMember (スタメン9人 + 控え)
                            ├─ has ──> ServiceOrder (サービス順)
                            ├─ has ──> Set (1〜3セット)
                            │           │
                            │           ├─ has ──> Formation
                            │           ├─ has ──> Substitution (選手交代)
                            │           ├─ has ──> Timeout
                            │           └─ has ──> Rally
                            │                       │
                            │                       └─ has ──> Play (プレー詳細)
                            │
                            └─ has ──> OpponentTeam (背番号のみ)
                                        │
                                        └─ has ──> OpponentPlayer (背番号)
```

### 2.2 主要エンティティ詳細

#### User
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | Supabase Auth から発行 |
| email | String? | Sign in with Apple の場合は private relay も可 |
| display_name | String | 表示名 |
| created_at | Timestamp | |

#### Team
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| owner_id | UUID | User.id への参照 |
| name | String | チーム名 |
| created_at | Timestamp | |
| updated_at | Timestamp | |

#### Player
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| team_id | UUID | Team.id への参照 |
| jersey_number | Int | 背番号 |
| name | String | 名前 |
| position_tendency | String? | ポジション傾向（任意・FL/FC/FR/HL/HC/HR/BL/BC/BR/カスタム） |
| is_active | Bool | 在籍中フラグ |
| created_at | Timestamp | |

> 制約：1チームあたり最大15人

#### Match
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| team_id | UUID | Team.id への参照 |
| recorder_id | UUID | User.id（Recorder） |
| match_code | String(6) | 試合コード（Viewer参加用） |
| match_code_expires_at | Timestamp | 試合コード有効期限 |
| date | Date | 試合日 |
| start_time | Timestamp | 開始時刻 |
| end_time | Timestamp? | 終了時刻 |
| opponent_team_name | String | 対戦相手名 |
| tournament_name | String? | 大会名 |
| match_type | Enum | official/practice/training_camp |
| venue | String? | 会場 |
| status | Enum | preparing/in_progress/finished/abandoned |
| created_at | Timestamp | |
| updated_at | Timestamp | |

#### MatchMember
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| match_id | UUID | |
| player_id | UUID | Player.id |
| is_starter | Bool | スタメンフラグ |

#### ServiceOrder
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| match_id | UUID | |
| order | Int | 1〜9 |
| starting_player_id | UUID | 開始時のスタメン選手 |
| current_player_id | UUID | 現時点でその順番にいる選手（交代後変わる） |

#### Set
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| match_id | UUID | |
| set_number | Int | 1, 2, 3 |
| formation | Enum | 5-1-3 / 6-3 / 4-2-3 / 3-3-3 / custom |
| custom_formation | String? | カスタム時の説明 |
| our_score_final | Int? | 終了時自得点 |
| opponent_score_final | Int? | 終了時相手得点 |
| started_at | Timestamp | |
| ended_at | Timestamp? | |

#### Substitution
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| set_id | UUID | |
| our_score | Int | |
| opponent_score | Int | |
| player_in_id | UUID | 入る選手 |
| player_out_id | UUID | 出る選手 |
| service_order_id | UUID | 影響を受けたサービス順 |
| substitution_count_in_set | Int | このセットで何回目（1〜4） |
| timestamp | Timestamp | |

#### Timeout
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| set_id | UUID | |
| our_score | Int | 取った時点のスコア |
| opponent_score | Int | |
| requesting_team | Enum | own/opponent |
| timeout_type | Enum | regular/medical |
| timestamp | Timestamp | |

> 制約：requesting_team='own' の Timeout は1セット2件まで

#### Rally
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| set_id | UUID | |
| rally_number | Int | セット内の何ラリー目か |
| start_score_us | Int | 開始時自スコア |
| start_score_opp | Int | 開始時相手スコア |
| serving_team | Enum | own/opponent |
| serving_player_id | UUID? | 自チームサーブの場合 |
| opponent_serving_jersey | Int? | 相手サーブの場合の背番号 |
| winner | Enum? | own/opponent（ラリー終了時） |
| started_at | Timestamp | |
| ended_at | Timestamp? | |

#### Play
| フィールド | 型 | 説明 |
|---|---|---|
| id | UUID | |
| rally_id | UUID | |
| sequence_in_rally | Int | ラリー内の順番（1, 2, 3...） |
| play_team | Enum | own/opponent |
| player_id | UUID? | 自チームの場合 |
| opponent_jersey | Int? | 相手の場合 |
| play_type | Enum | serve/reception/set/attack/block/dig/error |
| evaluation | Enum | excellent/good/normal/error（◎○△×） |
| serve_type | Enum? | float/jump/jump_float（サーブのみ） |
| serve_attempt | Enum? | first/second（サーブのみ・9人制特有） |
| reception_quality | Enum? | a_pass/b_pass/c_pass/d_pass（レセプションのみ） |
| attack_course | Enum? | cross/straight/inner/feint/other（詳細モード） |
| serve_course | Int? | 1-9（相手コートのゾーン、詳細モード） |
| block_count | Int? | 1/2/3（ブロック枚数） |
| error_type | Enum? | drilbble/over_times/touch_net/etc（ミス時） |
| timestamp | Timestamp | |
| video_offset_seconds | Float? | 動画同期用オフセット |
| is_assist | Bool | 自動計算：直前のセットが決定打に繋がったか |

### 2.3 集計指標の計算式

#### アタック決定率
```
attack_kill_rate = (決定数) / (打数) × 100
```
- 打数 = play_type='attack' のレコード数
- 決定数 = play_type='attack' AND evaluation='excellent' のレコード数

#### アタック効果率
```
attack_efficiency = (決定数 - 失点) / (打数) × 100
```
- 失点 = play_type='attack' AND evaluation='error' のレコード数

#### レセプションA率
```
reception_a_rate = (Aパス数) / (全レセプション数) × 100
```

#### レセプション返球率
```
reception_return_rate = (Aパス + Bパス + Cパス) / (全レセプション数) × 100
```

#### サービスエフィシェンシー
```
serve_efficiency = (サービスエース - サービスミス) / (全サーブ数) × 100
```

#### 連続得点
- 同一チームが連続で得点したラリーをカウント
- **3点以上で「ハイライト対象」**としてマーキング
- グラフ表示時に強調表示

### 2.4 アシスト自動計算ロジック

```
For each Play where play_type='attack' AND evaluation='excellent':
  Find the most recent Play in the same Rally where:
    play_type='set' AND play_team=own
  If found: that Play.is_assist = true
```

### 2.5 物理削除ポリシー

- 試合削除時：関連する Set, Substitution, Timeout, Rally, Play, MatchMember, ServiceOrder すべてを CASCADE で物理削除
- 選手削除時：その選手が含まれる試合がない場合のみ削除可能（外部キー制約）
- ラリー削除時：関連する Play を CASCADE で物理削除

> 削除前に必ずローカルにJSONバックアップを生成（F-1.0.21）

---

## 3. データバリデーションルール

### 3.1 試合作成時
- スタメンは正確に9人
- サービス順は1〜9をすべて含む
- 同一選手が複数のサービス順に登録されていないこと
- 試合コードは6桁の英数字（紛らわしい文字を除外：0/O, 1/I/l）

### 3.2 プレー入力時
- 自チームのプレーは player_id 必須
- 相手チームのプレーは opponent_jersey 必須
- play_type と evaluation の組み合わせが論理的に成立すること
  - 例：play_type='reception' なら reception_quality も記録

### 3.3 試合進行
- スコアは0以上、各セット30点以下（21点 + デュース余裕）
- 1セット2 タイムアウト/チーム を超えない
- 1セット4 選手交代 を超えない
- 1選手の再交代は1セット1回まで
