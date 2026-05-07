// RecorderClaim — Recorder衝突防止 (current_recorder_device_id ベース)
//
// 同じ試合に2台目が接続したとき、Recorder は1台のみ。後発端末は自動 Viewer に。

import Foundation

public enum RecorderRole: Equatable, Sendable {
    case recorder
    case viewer
}

public protocol RecorderClaimClient: Sendable {
    /// 該当試合の Recorder claim を取りに行く
    /// - 自端末が既に Recorder なら .recorder
    /// - 他端末が Recorder で生きている場合は .viewer
    func tryBecomeRecorder(matchId: UUID, deviceId: String, currentUserId: UUID) async throws -> RecorderRole

    /// Recorder 引き継ぎ (明示的)
    func forceTakeoverRecorder(matchId: UUID, deviceId: String, currentUserId: UUID) async throws
}

/// テスト・Preview 用 Mock。常に .recorder を返す
public struct MockRecorderClaimClient: RecorderClaimClient {
    public var role: RecorderRole

    public init(role: RecorderRole = .recorder) {
        self.role = role
    }

    public func tryBecomeRecorder(matchId: UUID, deviceId: String, currentUserId: UUID) async throws -> RecorderRole {
        role
    }

    public func forceTakeoverRecorder(matchId: UUID, deviceId: String, currentUserId: UUID) async throws {}
}
