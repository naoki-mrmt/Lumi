# M5: 振り返り・PDF/CSV出力

## 目的

試合終了後の振り返り画面、PDF サマリ生成、CSV エクスポート、iOS 共有シート連携、削除前バックアップ JSON 生成を実装。アナリストが実戦投入後に「次戦のために」必要な情報を吐き出せる状態にする。

## 完了条件（DoD）

- [ ] ReviewFeature がライブビューから振り返りビューへの遷移を担う
- [ ] 試合終了 → 自動的に振り返り画面へ遷移
- [ ] 全セット俯瞰モードで全試合のKPIが見られる
- [ ] PDFGenerator が試合サマリPDFを生成可能（A4・1〜2枚）
- [ ] CSV エクスポートが選手別集計と全プレーログを出力
- [ ] iOS共有シート経由で AirDrop / メール / LINE 等に共有可能
- [ ] 試合削除前にローカルJSONバックアップが自動生成される
- [ ] PDF レイアウトのスナップショットテストが緑

## 関連ドキュメント

- `docs/02_FEATURE_SPEC.md` — F-1.0.15, F-1.0.16, F-1.0.21
- `docs/04_UI_DESIGN.md` — 6.4 振り返り画面、10 PDFレイアウト
- `docs/03_DOMAIN_MODEL.md` — 集計指標
- `docs/08_NON_FUNCTIONAL.md` — パフォーマンス目標（PDF 5秒以内）

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M5-T1 | ReviewFeature 骨格 | TCA Feature・ライブ→振り返り遷移ロジック |
| M5-T2 | 試合終了→振り返り画面遷移 | 試合終了Action でビューが切替 |
| M5-T3 | PDFGenerator（試合サマリ） | TPPDF or PDFKit で A4・1〜2枚生成 |
| M5-T4 | CSV出力 | 選手別集計 + 全プレーログ |
| M5-T5 | iOS共有シート連携 | UIActivityViewController / ShareLink で共有 |
| M5-T6 | 削除前バックアップJSON生成 | Filesアプリで参照可能な場所に保存 |

## 実装メモ

### ReviewFeatureの遷移ロジック

`MatchInputFeature` で「試合終了」アクションが発火 → 親の `AppFeature` が `MatchViewerFeature` から `ReviewFeature` へ切替。

```swift
@Reducer
public struct AppFeature {
  @ObservableState
  public struct State: Equatable {
    var route: Route = .home
  }
  
  public enum Route: Equatable {
    case home
    case matchSetup(MatchSetupFeature.State)
    case matchInput(MatchInputFeature.State)    // Recorder
    case matchViewer(MatchViewerFeature.State)  // Viewer (live)
    case review(ReviewFeature.State)            // 振り返り
  }
  
  public enum Action {
    // ...
    case matchInput(MatchInputFeature.Action)
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .matchInput(.matchEnded(let match)):
          state.route = .review(ReviewFeature.State(match: match))
          return .none
        // ...
        }
      }
    }
  }
}
```

### PDF生成

PDFKit を使用（軽量・依存なし）：

```swift
import PDFKit

public struct PDFGenerator {
  public func generateMatchSummary(match: Match) -> Data {
    let pdfDocument = PDFDocument()
    
    // ページ1: スコア・チーム集計
    let page1 = renderPage1(match: match)
    pdfDocument.insert(page1, at: 0)
    
    // ページ2: 選手別集計（出場選手のみ）
    let page2 = renderPage2(match: match)
    pdfDocument.insert(page2, at: 1)
    
    return pdfDocument.dataRepresentation() ?? Data()
  }
  
  private func renderPage1(match: Match) -> PDFPage {
    let pageSize = CGSize(width: 595, height: 842)  // A4
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
    
    let data = renderer.pdfData { ctx in
      ctx.beginPage()
      // 試合タイトル
      drawTitle(at: CGPoint(x: 40, y: 40), match: match)
      // チーム集計テーブル
      drawTeamStats(at: CGPoint(x: 40, y: 120), match: match)
      // ...
    }
    
    return PDFDocument(data: data)?.page(at: 0) ?? PDFPage()
  }
}
```

### PDFレイアウト原則（再掲）

`docs/04_UI_DESIGN.md` 10.2 デザイン要件：
- 白背景・黒文字（紙印刷想定）
- フォントは SF Pro系
- 数値は等幅で揃える
- アクセントはグレー系のみ

### CSV出力フォーマット

#### 選手別集計CSV

```
プレイヤーNo,プレイヤー名,セット,出場,アタック打数,アタック決定,アタック失点,決定率,効果率,...
7,田中,1,YES,12,5,2,41.7%,25.0%,...
4,佐藤,1,YES,3,1,0,33.3%,33.3%,...
...
```

#### 全プレーログCSV

```
セット,ラリー,順番,チーム,選手,プレー種別,評価,詳細
1,1,1,自,7,サーブ,◎,ジャンプサーブ
1,1,2,相手,11,アタック,×,ストレート
...
```

### 共有シート連携

```swift
import SwiftUI

ShareLink(
  item: pdfData,
  preview: SharePreview(
    "試合サマリ - \(match.opponentTeamName)",
    image: Image(systemName: "doc.text")
  )
)
```

iOS 16+ なら `ShareLink`、それ以前は `UIActivityViewController`。本プロジェクトは iOS 26+ なので問題なし。

### 削除前バックアップJSON

```swift
public func deleteMatchSafely(match: Match) async throws {
  // 1. JSONバックアップ生成
  let backupData = try JSONEncoder.iso8601().encode(match)
  let backupURL = URL.documentsDirectory
    .appendingPathComponent("backup_\(match.id.uuidString)_\(Date().ISO8601Format()).json")
  try backupData.write(to: backupURL)
  
  // 2. Filesアプリで見える場所にも保存
  if let documentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
    try backupData.write(to: documentsURL.appendingPathComponent("backup.json"))
  }
  
  // 3. ユーザーに保存場所を通知
  // ...
  
  // 4. Supabase 削除
  try await supabase.from("matches").delete().eq("id", value: match.id).execute()
  
  // 5. ローカル削除
  try await localStore.delete(match)
}
```

### 試合データのスナップショットテスト

PDFのレイアウトがリグレッションしないよう、テスト用ダミー試合で生成PDFを画像化してスナップショット：

```swift
@Test
func pdfSummaryLayoutLightMode() {
  let dummyMatch = MockData.fullMatch  // 全データが詰まったダミー試合
  let pdfData = PDFGenerator().generateMatchSummary(match: dummyMatch)
  let firstPageImage = renderFirstPageAsImage(pdfData)
  assertSnapshot(of: firstPageImage, as: .image)
}
```

## CC に渡すプロンプト雛形

```
M5 を進めてほしい。
docs/progress.json で M4 が completed であることを確認。
docs/04_UI_DESIGN.md の10章 PDFレイアウト と
docs/02_FEATURE_SPEC.md F-1.0.15〜21 の仕様を確認。

特に：
- M5-T3: PDFは A4・1〜2枚に収める。docs/04_UI_DESIGN.md 10.1 のレイアウト準拠
- M5-T6: 削除前バックアップは Files アプリで見える場所に保存（CASCADE削除前必須）
- PDF レイアウトは必ずスナップショットテストを書く（リグレッション検知）

各タスク完了ごとに progress.json 更新。
```
