// VideoPlaybackService — プレーから動画 seek 再生 (Phase 2.2 本格版の API 抽象)
//
// AVPlayer をラップする。実装は iOS 限定 (UIKit / AVKit 依存)。

import Foundation
import Models

public protocol VideoPlaybackService: Sendable {
    func loadVideo(at url: URL) async throws
    func seek(toSeconds seconds: TimeInterval) async
    func play() async
    func pause() async
    /// 現在の再生位置 (秒)。動画未ロードなら nil
    func currentSeconds() async -> TimeInterval?
}

public final class MockVideoPlaybackService: VideoPlaybackService, @unchecked Sendable {
    public private(set) var loadedURL: URL?
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var isPlaying: Bool = false

    public init() {}

    public func loadVideo(at url: URL) async throws { loadedURL = url }
    public func seek(toSeconds seconds: TimeInterval) async { currentTime = seconds }
    public func play() async { isPlaying = true }
    public func pause() async { isPlaying = false }
    public func currentSeconds() async -> TimeInterval? { loadedURL != nil ? currentTime : nil }
}

public extension VideoPlaybackService {
    /// プレーに対応する動画位置に seek + 再生
    func seekAndPlay(forPlay aPlay: Play, match: Match) async {
        guard let offset = VideoSync.videoOffset(forPlay: aPlay, match: match) else { return }
        await seek(toSeconds: offset)
        await self.play()
    }
}
