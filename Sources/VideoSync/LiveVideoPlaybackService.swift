// LiveVideoPlaybackService — AVPlayer ベース実装 (Phase 2.2 Live)

import Foundation
#if canImport(AVKit)
import AVKit
import AVFoundation

public final class LiveVideoPlaybackService: VideoPlaybackService, @unchecked Sendable {
    private let player: AVPlayer

    public init() {
        self.player = AVPlayer()
    }

    public func loadVideo(at url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        await MainActor.run { player.replaceCurrentItem(with: item) }
    }

    public func seek(toSeconds seconds: TimeInterval) async {
        await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    public func play() async {
        await MainActor.run { player.play() }
    }

    public func pause() async {
        await MainActor.run { player.pause() }
    }

    public func currentSeconds() async -> TimeInterval? {
        await MainActor.run {
            guard player.currentItem != nil else { return nil as TimeInterval? }
            return player.currentTime().seconds
        }
    }
}

#endif
