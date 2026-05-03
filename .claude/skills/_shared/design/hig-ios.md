# Apple Human Interface Guidelines — クイックリファレンス

## 基本原則
- **Clarity**: コンテンツが主役。UIは情報伝達を支援する
- **Deference**: UIはコンテンツを引き立てる。目立ちすぎない
- **Depth**: レイヤー・トランジション・ジェスチャーで空間感

## ナビゲーション
- **フラット構造**: TabView (iOS), Sidebar (macOS) — 並列コンテンツ
- **階層構造**: NavigationStack — ドリルダウン
- **モーダル**: sheet / fullScreenCover — 独立タスク、完了/キャンセルが明確

### macOS 固有
- メニューバーアプリはシンプルに、設定は別ウインドウ
- Popover は軽量な操作向け（複雑なフローには使わない）
- Settings は SwiftUI Settings scene を使用

### iOS 固有
- Tab は 3-5 個まで
- 重要なアクションは親指の届く範囲に
- Safe Area を尊重

## タイポグラフィ
- システムフォント使用 (SF Pro / SF Mono)
- Dynamic Type 対応必須
- 最小タッチターゲット: 44x44pt (iOS), 適切なクリック領域 (macOS)

## カラー
- システムカラー使用 (Color.primary, .secondary, .accentColor)
- ダークモード必須対応
- コントラスト比 4.5:1 以上 (テキスト)

## アイコン
- SF Symbols 使用推奨
- サイズとウェイトはテキストに合わせる
- アクセシビリティラベル必須（テキストなしの場合）

## フィードバック
- 操作結果は即時フィードバック
- 破壊的操作は確認ダイアログ
- ローディング状態を明示 (ProgressView)
- Haptics (iOS) は控えめに、意味のある場面で

## macOS 固有ガイドライン
- メニューバーアイテムは Template Image を使用
- ウインドウサイズは適切なデフォルトとリサイズ対応
- キーボードショートカット提供
- ドラッグ&ドロップ対応

## iOS 固有ガイドライン
- ジェスチャーは標準的なもの（スワイプ、ピンチ等）
- 横向き対応（必要な場合）
- iPadでの Multitasking / Split View 対応

## レビューチェック
- [ ] ダークモード対応しているか
- [ ] Dynamic Type で崩れないか
- [ ] VoiceOver で操作可能か
- [ ] SF Symbols を使っているか（カスタムアイコンの前に検討）
- [ ] 標準コンポーネントを使っているか（カスタムの前に検討）
- [ ] macOS / iOS 両方で適切な UX か
