// Telemetry — Sentry / OSLog ラッパー
//
// docs/specs/M8-observability.md 準拠

import Foundation
import Sentry
import OSLog

public enum Telemetry {
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

        Logger.telemetryInternal.info("Sentry initialized: env=\(environment, privacy: .public)")
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

    /// Breadcrumb 追加 (PII を含めないこと)
    public static func breadcrumb(
        category: BreadcrumbCategory,
        message: String,
        data: [String: String]? = nil
    ) {
        let crumb = Breadcrumb(level: .info, category: category.rawValue)
        crumb.message = message
        if let data {
            crumb.data = data
        }
        SentrySDK.addBreadcrumb(crumb)
    }

    /// 計測ブロック
    public static func measure<T: Sendable>(
        _ name: String,
        op: String,
        block: @Sendable () async throws -> T
    ) async rethrows -> T {
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

    /// 例外を Sentry に送信
    public static func capture(_ error: Error) {
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
