// BatteryMonitor 純関数 / Mock テスト

import Foundation
import Testing
@testable import Telemetry

@Suite("BatteryMonitor")
struct BatteryMonitorTests {
    @Test("BatteryLevel.fraction から区分が決まる")
    func levelFromFraction() {
        #expect(BatteryLevel(fraction: -1) == .unknown)
        #expect(BatteryLevel(fraction: 0.05) == .critical)
        #expect(BatteryLevel(fraction: 0.20) == .low)
        #expect(BatteryLevel(fraction: 0.50) == .normal)
        #expect(BatteryLevel(fraction: 0.95) == .high)
        #expect(BatteryLevel(fraction: 1.0) == .high)
    }

    @Test("needsWarning は low / critical のみ true")
    func needsWarning() {
        #expect(BatteryLevel.high.needsWarning == false)
        #expect(BatteryLevel.normal.needsWarning == false)
        #expect(BatteryLevel.low.needsWarning)
        #expect(BatteryLevel.critical.needsWarning)
        #expect(BatteryLevel.unknown.needsWarning == false)
    }

    @Test("MockBatteryMonitor が stub を返す")
    func mockBattery() async {
        let m = MockBatteryMonitor()
        m.stubLevel = .critical
        m.stubCharging = true
        #expect(await m.currentLevel() == .critical)
        #expect(await m.isCharging())
    }
}
