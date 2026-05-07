// SupabaseClient — Supabase SDK ラッパー
//
// Bundle.main.infoDictionary に SUPABASE_URL / SUPABASE_ANON_KEY / SENTRY_DSN を
// 注入する想定 (Info.plist 経由)。未設定の場合は nil を返す (fatalError しない)。
// 開発時は SupabaseClientProvider.shared が nil であれば Mock 実装にフォールバックする。

import Foundation
import Supabase

public struct AppConfig {
    /// Supabase プロジェクト URL。Info.plist 未設定時は nil
    public static var supabaseURL: URL? {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty,
              !urlString.contains("YOUR_PROJECT"),
              let url = URL(string: urlString)
        else { return nil }
        return url
    }

    /// Supabase anon key。Info.plist 未設定時は nil
    public static var supabaseAnonKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty,
              !key.contains("YOUR_ANON_KEY")
        else { return nil }
        return key
    }

    /// Sentry DSN。未設定時は空文字 (Telemetry 側で空ならスキップ)
    public static var sentryDSN: String {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !dsn.isEmpty,
              !dsn.contains("YOUR_DSN")
        else { return "" }
        return dsn
    }

    public static var environment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    /// Live Supabase 接続が利用可能かどうか
    public static var isConfigured: Bool {
        supabaseURL != nil && supabaseAnonKey != nil
    }
}

public enum SupabaseClientProvider {
    public static func makeClient(url: URL, anonKey: String) -> SupabaseClient {
        SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    /// AppConfig から構築したシングルトン。Info.plist 未設定時は nil
    public static let shared: SupabaseClient? = {
        guard let url = AppConfig.supabaseURL,
              let key = AppConfig.supabaseAnonKey
        else { return nil }
        return makeClient(url: url, anonKey: key)
    }()
}
