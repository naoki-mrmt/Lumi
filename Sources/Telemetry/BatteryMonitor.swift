// BatteryMonitor — M7-T6 バッテリー低下警告
//
// 役割: 試合中に iPad のバッテリーが残り少なくなったら、
// Recorder に「外部電源接続を推奨」「クラウドバックアップを優先」等の警告を出す。
//
// プロトコル抽象化により、テスト時はモック、Live は UIDevice ベース。

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum BatteryLevel: Equatable, Sendable {
    /// 80% 以上 (フル付近)
    case high
    /// 30〜80%
    case normal
    /// 10〜30%
    case low
    /// 10% 未満
    case critical
    /// 不明 (Simulator / 取得失敗)
    case unknown

    public init(fraction: Float) {
        switch fraction {
        case ..<0:                  self = .unknown
        case 0..<0.10:              self = .critical
        case 0.10..<0.30:           self = .low
        case 0.30..<0.80:           self = .normal
        default:                    self = .high
        }
    }

    /// ユーザに警告を出すべきかどうか
    public var needsWarning: Bool {
        self == .low || self == .critical
    }
}

public protocol BatteryMonitor: Sendable {
    func currentLevel() async -> BatteryLevel
    func isCharging() async -> Bool
}

public final class MockBatteryMonitor: BatteryMonitor, @unchecked Sendable {
    public var stubLevel: BatteryLevel = .normal
    public var stubCharging: Bool = false
    public init() {}
    public func currentLevel() async -> BatteryLevel { stubLevel }
    public func isCharging() async -> Bool { stubCharging }
}

#if canImport(UIKit)
public final class LiveBatteryMonitor: BatteryMonitor, @unchecked Sendable {
    public init() {
        Task { @MainActor in
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
    }

    public func currentLevel() async -> BatteryLevel {
        let level: Float = await MainActor.run { UIDevice.current.batteryLevel }
        return BatteryLevel(fraction: level)
    }

    public func isCharging() async -> Bool {
        let state = await MainActor.run { UIDevice.current.batteryState }
        return state == .charging || state == .full
    }
}
#endif
