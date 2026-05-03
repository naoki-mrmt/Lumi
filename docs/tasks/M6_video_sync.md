# M6: 動画後付け同期

## 目的

別撮りで撮影した試合動画ファイルをアプリに取り込み、各プレーのタイムスタンプから動画の該当シーンに自動でジャンプできる「動画 × 数値」連携の簡易版（Phase 1）を実装。Phase 2.2 で本格版に拡張する前提。

## 完了条件（DoD）

- [ ] 動画ファイル（mp4/mov）をアプリに取り込み可能
- [ ] 試合開始時刻と動画のタイムスタンプを1点合わせる UI が動作
- [ ] 各プレーの timestamp から動画オフセット秒数を計算
- [ ] 数値クリック → 該当シーンに動画ジャンプ・再生（簡易版）
- [ ] 動画は端末ローカル保存（Phase 2.2でクラウド連携検討）

## 関連ドキュメント

- `docs/02_FEATURE_SPEC.md` — F-1.0.17
- `docs/03_DOMAIN_MODEL.md` — Play.video_offset_seconds
- `docs/09_ROADMAP.md` — Phase 2.2 で本格版

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M6-T1 | 動画ファイルアップロードUI | DocumentPicker で mp4/mov 選択 |
| M6-T2 | 試合開始時刻同期UI | 動画再生中に「ここが試合開始」をマーク |
| M6-T3 | プレー→動画タイムスタンプ計算 | Play.timestamp と videoStartOffset から計算 |
| M6-T4 | 数値クリック→動画再生（簡易版） | AVPlayer で該当シーンから再生 |

## 実装メモ

### 動画ファイルの取り込み

```swift
import UniformTypeIdentifiers
import SwiftUI

struct VideoPickerView: View {
  @State private var showingPicker = false
  @State private var videoURL: URL?
  
  var body: some View {
    Button("動画を選択") {
      showingPicker = true
    }
    .fileImporter(
      isPresented: $showingPicker,
      allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
      onCompletion: { result in
        if case .success(let url) = result {
          videoURL = url
          // Documents Directory にコピー
        }
      }
    )
  }
}
```

### 試合開始時刻同期 UI

シンプルなUI：動画を再生しながら、開始時点で「ここを試合開始としてマーク」ボタン。

```
┌──────────────────────────────────────┐
│  [動画プレイヤー]                     │
│                                       │
│  ▶ ─●────────────────────────         │
│   00:00:32                            │
│                                       │
│  [ ここを試合開始としてマーク ]        │
└──────────────────────────────────────┘
```

押した時点の動画タイムスタンプ（00:00:32）を保存。

### 動画オフセット計算

```swift
public struct VideoSync {
  public func videoOffsetForPlay(_ play: Play, match: Match) -> TimeInterval? {
    guard let videoStartOffset = match.videoStartOffsetSeconds else {
      return nil  // 動画未同期
    }
    
    let elapsedFromMatchStart = play.timestamp.timeIntervalSince(match.startTime)
    return videoStartOffset + elapsedFromMatchStart
  }
}
```

### プレー → シーン再生

```swift
struct PlayVideoView: View {
  let play: Play
  let match: Match
  let videoURL: URL
  
  @State private var player: AVPlayer?
  
  var body: some View {
    VideoPlayer(player: player)
      .onAppear {
        let p = AVPlayer(url: videoURL)
        if let offset = VideoSync().videoOffsetForPlay(play, match: match) {
          p.seek(to: CMTime(seconds: offset, preferredTimescale: 600))
        }
        p.play()
        player = p
      }
  }
}
```

### Phase 2.2 拡張の前提

- 数値クリック→動画ジャンプは簡易版でOK（タップ可能・誤差±1〜2秒）
- 本格版（クリップ抽出・ハイライト動画作成等）はPhase 2.2

### 動画ファイルの保存場所

- Documents Directory（iCloudバックアップ対象外にする：容量考慮）
- 試合削除時に動画ファイルも削除

```swift
extension URL {
  static var videosDirectory: URL {
    let url = URL.documentsDirectory.appendingPathComponent("videos", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    
    // iCloudバックアップ対象外に
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var mutableURL = url
    try? mutableURL.setResourceValues(resourceValues)
    
    return url
  }
}
```

### Q-002 についての注記

`docs/10_DESIGN_DECISIONS.md` Q-002：「動画同期のタイムスタンプずれの許容範囲」が未決定。M6 実装時に：
1. 実際の試合動画でテスト
2. 1秒・2秒・3秒のずれをユーザーが「気になる/気にならない」のテスト
3. 結果を `10_DESIGN_DECISIONS.md` に記録
4. progress.json の open_questions[Q-002] を resolved に更新

## CC に渡すプロンプト雛形

```
M6 を進めてほしい。
docs/progress.json で M5 が completed であることを確認。
これは Phase 1 の簡易版なので、深追いしなくてOK。
詳細な動画連携は Phase 2.2 で行う。

特に：
- M6-T2: シンプルなマーカーUIで十分
- M6-T4: AVPlayer で seek + play の最低限実装
- 動画ファイルは iCloud バックアップ対象外に設定（容量問題回避）

実装中、Q-002（タイムスタンプずれの許容範囲）について
気づきがあれば docs/10_DESIGN_DECISIONS.md に記録。

各タスク完了ごとに progress.json 更新。
```
