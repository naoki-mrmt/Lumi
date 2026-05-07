// VideoSync — 動画タイムスタンプ計算 (純粋関数)

import Foundation
import Models

public enum VideoSync: Sendable {
    /// プレーの動画タイムスタンプ (秒) を計算。
    /// 動画未同期の場合は nil を返す。
    public static func videoOffset(forPlay play: Play, match: Match) -> TimeInterval? {
        guard let videoStart = match.videoStartOffsetSeconds else { return nil }
        let elapsed = play.timestamp.timeIntervalSince(match.startTime)
        return videoStart + elapsed
    }

    /// 任意のタイムスタンプから動画オフセットを計算
    public static func videoOffset(at timestamp: Date, match: Match) -> TimeInterval? {
        guard let videoStart = match.videoStartOffsetSeconds else { return nil }
        let elapsed = timestamp.timeIntervalSince(match.startTime)
        return videoStart + elapsed
    }
}
