// Telemetry — Sentry / OSLog ラッパー
//
// docs/specs/M8-observability.md 準拠

import Foundation
import os
import Sentry
import OSLog

public enum Telemetry {
    /// Sentry SDK が起動済みかどうか。breadcrumb / measure のガードに使う。
    /// `OSAllocatedUnfairLock` で保護し、Swift 6 strict concurrency 下でも race-free。
    private static let sdkStartedLock = OSAllocatedUnfairLock<Bool>(initialState: false)
    private static var sdkStarted: Bool {
        sdkStartedLock.withLock { $0 }
    }
    private static func setSDKStarted(_ value: Bool) {
        sdkStartedLock.withLock { $0 = value }
    }

    /// Sentry SDK 初期化。M0 で骨格、M8 で本格化。
    public static func start(
        dsn: String,
        environment: String,
        tracesSampleRate: Double = 1.0
    ) {
        guard !dsn.isEmpty else {
            Logger.telemetryInternal.warning("Sentry DSN が未設定。クラッシュレポートは無効")
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.tracesSampleRate = NSNumber(value: tracesSampleRate)
            options.enableAutoBreadcrumbTracking = true
            #if canImport(UIKit)
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            #endif
            options.beforeSend = sanitizeEvent
        }
        setSDKStarted(true)

        Logger.telemetryInternal.info("Sentry initialized: env=\(environment, privacy: .public)")
    }

    /// 本番環境で Sentry が正しく届くかを確認するためのテストイベント送信。
    /// 開発時に設定画面のデバッグメニュー等から呼び出す想定。
    public static func sendTestEvent(message: String = "Lumi test event") {
        guard sdkStarted else {
            Logger.telemetryInternal.warning("Sentry 未起動のため testEvent を送信不可")
            return
        }
        SentrySDK.capture(message: message)
        Logger.telemetryInternal.info("Sentry test event sent: \(message, privacy: .public)")
    }

    /// PII サニタイズ
    private static func sanitizeEvent(_ event: Event) -> Event? {
        // メール / ユーザー名は送らない
        event.user?.email = nil
        event.user?.username = nil

        // コンテキストの PII っぽいキーをマスク
        if var contexts = event.context {
            for (key, value) in contexts {
                var dict = value
                for piiKey in ["opponent_team_name", "player_name", "team_name", "email"] {
                    if dict[piiKey] != nil { dict[piiKey] = "***" }
                }
                contexts[key] = dict
            }
            event.context = contexts
        }
        return event
    }

    /// Breadcrumb 追加 (PII を含めないこと)。Sentry 未起動時は no-op。
    public static func breadcrumb(
        category: BreadcrumbCategory,
        message: String,
        data: [String: String]? = nil
    ) {
        guard sdkStarted else { return }
        let crumb = Breadcrumb(level: .info, category: category.rawValue)
        crumb.message = message
        if let data {
            crumb.data = data
        }
        SentrySDK.addBreadcrumb(crumb)
    }

    /// 計測ブロック。Sentry 未起動時は block をそのまま実行 (no-op)。
    public static func measure<T: Sendable>(
        _ name: String,
        op: String,
        block: @Sendable () async throws -> T
    ) async rethrows -> T {
        guard sdkStarted else { return try await block() }
        let transaction = SentrySDK.startTransaction(name: name, operation: op)
        do {
            let result = try await block()
            transaction.finish(status: .ok)
            return result
        } catch {
            transaction.finish(status: .internalError)
            throw error
        }
    }

    /// 例外を Sentry に送信。Sentry 未起動時は no-op (OSLog のみ残す)。
    public static func capture(_ error: Error) {
        guard sdkStarted else {
            Logger.telemetryInternal.error("captured (Sentry off): \(error.localizedDescription, privacy: .public)")
            return
        }
        SentrySDK.capture(error: error)
    }
}

public enum BreadcrumbCategory: String, Sendable {
    case match, input, sync, auth, stats, ui
}

// MARK: - OSLog Categories

extension Logger {
    static let telemetryInternal = Logger(subsystem: "com.muramoto-co.lumi", category: "telemetry")
    public static let app = Logger(subsystem: "com.muramoto-co.lumi", category: "app")
    public static let sync = Logger(subsystem: "com.muramoto-co.lumi", category: "sync")
    public static let input = Logger(subsystem: "com.muramoto-co.lumi", category: "input")
    public static let auth = Logger(subsystem: "com.muramoto-co.lumi", category: "auth")
    public static let stats = Logger(subsystem: "com.muramoto-co.lumi", category: "stats")
    public static let pdf = Logger(subsystem: "com.muramoto-co.lumi", category: "pdf")
    public static let video = Logger(subsystem: "com.muramoto-co.lumi", category: "video")
    public static let ui = Logger(subsystem: "com.muramoto-co.lumi", category: "ui")
    public static let match = Logger(subsystem: "com.muramoto-co.lumi", category: "match")
}

// 旧 API 互換 (M0 で書いた TelemetryBootstrap.start を維持)
public enum TelemetryBootstrap {
    public static func start(dsn: String, environment: String) {
        Telemetry.start(dsn: dsn, environment: environment)
    }
}
