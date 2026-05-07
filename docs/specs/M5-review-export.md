# 仕様書: M5 — 振り返り・PDF/CSV出力

**Status**: draft
**作成日**: 2026-05-04

---

## 1. 目的

試合終了後の振り返り画面、PDF サマリ、CSV エクスポート、削除前バックアップ。

## 2. スコープ

| モジュール | 役割 |
|---|---|
| `ReviewFeature` | 振り返りビュー + 遷移 |
| `PDFGenerator` | PDFKit で試合サマリ A4 を生成 |
| (新規) `CSVExporter` | 選手別集計 / 全プレーログを CSV 文字列に |
| (新規) `MatchBackup` | Match を JSON エンコードして書き出し |

## 3. CSV フォーマット

### 3.1 選手別集計 (player_stats.csv)
```
player_id,jersey,attack_attempts,attack_kills,kill_rate,efficiency,reception_attempts,a_pass_rate,serve_attempts,serve_aces,assists,block_kills,digs
```

### 3.2 全プレーログ (plays.csv)
```
set_number,rally_number,sequence,team,player_id,jersey,play_type,evaluation,serve_type,reception_quality,attack_course,is_assist,timestamp
```

## 4. PDF レイアウト (A4)

ページ 1: 試合タイトル + チーム集計 (自/相手)
ページ 2: 選手別集計 + セット別比較

白背景・黒文字・SF Pro Rounded・Tabular Numbers。

## 5. ReviewFeature

State + Reducer:
```swift
@Reducer
public struct ReviewFeature {
    @ObservableState
    public struct State: Equatable {
        public var match: Match
        public var stats: TeamStats = .empty
        public var generatingPDF: Bool = false
        public var pdfData: Data?
        public var csvData: Data?
    }
    public enum Action {
        case onAppear
        case generatePDFTapped
        case pdfGenerated(Data)
        case generateCSVTapped
        case csvGenerated(Data)
    }
}
```

## 6. テスト戦略

- `CSVExporter` 純粋関数のテスト (フォーマット検証)
- `MatchBackup` JSON ラウンドトリップ
- `PDFGenerator` は data.count > 0 と最低1ページ生成のみ検証 (画素単位スナップショットは将来)

## 7. 完了判定

- [ ] ReviewFeature + View
- [ ] PDFGenerator (実 PDFKit)
- [ ] CSVExporter + テスト
- [ ] MatchBackup + テスト
- [ ] iPad iOS 26 ビルド緑
- [ ] AppFeature から振り返り画面に遷移できる

## 8. 段取り

1. CSVExporter (純粋関数) + テスト
2. MatchBackup + テスト
3. PDFGenerator (PDFKit, iOS のみ — テストはコンパイルできるようマクロガード)
4. ReviewFeature Reducer + View
5. AppFeature の matchInput → review 遷移
