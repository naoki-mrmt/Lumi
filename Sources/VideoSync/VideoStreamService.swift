// VideoStreamService — Phase 2.3 6秒遅延映像配信
//
// 撮影端末→ベンチ端末への配信機構を抽象化。
// 実装は WebRTC + ローカル Wi-Fi (Phase 2.3 で具体化)。

import Foundation

public protocol VideoStreamService: Sendable {
    /// 配信開始 (撮影側)
    func startBroadcasting() async throws
    /// 配信停止
    func stopBroadcasting() async
    /// 受信開始 (ベンチ側)、配信中の端末を検索
    func startReceiving() async throws -> AsyncStream<VideoStreamFrame>
    /// 受信停止
    func stopReceiving() async
    /// 同時にローカル録画を開始 (mp4 で Documents 配下)
    func startLocalRecording(to url: URL) async throws
    func stopLocalRecording() async throws -> URL
}

public struct VideoStreamFrame: Sendable {
    public let timestamp: Date
    public let payload: Data    // エンコード済みフレーム

    public init(timestamp: Date, payload: Data) {
        self.timestamp = timestamp
        self.payload = payload
    }
}

/// 6秒遅延バッファ。フレームを受け取って 6 秒後に流す。
public actor DelayedFrameBuffer {
    private var entries: [VideoStreamFrame] = []
    private let delay: TimeInterval

    public init(delay: TimeInterval = 6.0) {
        self.delay = delay
    }

    public func enqueue(_ frame: VideoStreamFrame) {
        entries.append(frame)
    }

    /// `now` 時点で「`delay` 秒以上前のフレーム」を pop
    public func popReady(now: Date = Date()) -> [VideoStreamFrame] {
        let threshold = now.addingTimeInterval(-delay)
        let (ready, remaining) = entries.partitioned { $0.timestamp <= threshold }
        entries = remaining
        return ready
    }

    public func count() -> Int { entries.count }
}

private extension Array {
    func partitioned(by belongsInFirst: (Element) -> Bool) -> ([Element], [Element]) {
        var first: [Element] = []
        var second: [Element] = []
        for e in self {
            if belongsInFirst(e) { first.append(e) } else { second.append(e) }
        }
        return (first, second)
    }
}

public final class MockVideoStreamService: VideoStreamService, @unchecked Sendable {
    public private(set) var isBroadcasting = false
    public private(set) var isReceiving = false
    public private(set) var recordingURL: URL?

    public init() {}

    public func startBroadcasting() async throws { isBroadcasting = true }
    public func stopBroadcasting() async { isBroadcasting = false }

    public func startReceiving() async throws -> AsyncStream<VideoStreamFrame> {
        isReceiving = true
        return AsyncStream { _ in }
    }
    public func stopReceiving() async { isReceiving = false }

    public func startLocalRecording(to url: URL) async throws {
        recordingURL = url
    }
    public func stopLocalRecording() async throws -> URL {
        guard let url = recordingURL else { throw NSError(domain: "VideoStream", code: -1) }
        recordingURL = nil
        return url
    }
}
