// AppError — グローバルエラー型と重大度

import Foundation

public enum AppError: Error, Equatable, Identifiable, Sendable {
    case network(NetworkErrorKind)
    case auth(AuthErrorKind)
    case sync(SyncErrorKind)
    case validation(ValidationErrorKind)
    case dataInconsistency(reason: String)
    case migration(reason: String)
    case unknown(message: String)

    public var id: String {
        switch self {
        case let .network(k): "network.\(k.rawValue)"
        case let .auth(k): "auth.\(k.rawValue)"
        case let .sync(k): "sync.\(k.rawValue)"
        case let .validation(k): "validation.\(k.rawValue)"
        case let .dataInconsistency(r): "dataInconsistency.\(r)"
        case let .migration(r): "migration.\(r)"
        case let .unknown(m): "unknown.\(m)"
        }
    }

    public var userMessage: String {
        switch self {
        case .network(.disconnected):
            "ネットワークから切断されました。オフラインモードで継続します。"
        case .network(.timeout):
            "通信がタイムアウトしました。しばらくしてから再試行してください。"
        case .auth(.signInFailed):
            "サインインに失敗しました。"
        case .auth(.sessionExpired):
            "セッションが切れました。再度サインインしてください。"
        case .sync(.bufferFull):
            "未同期のデータが多数あります。ネット環境のよい場所で同期してください。"
        case .sync(.maxAttemptsExceeded):
            "同期に複数回失敗しました。手動でリトライしてください。"
        case .validation(.invalidScore):
            "スコアが不正です。"
        case .validation(.invalidLineup):
            "スタメンが9人ではありません。"
        case .validation(.duplicatePlayer):
            "選手が重複しています。"
        case .validation(.substitutionLimitExceeded):
            "選手交代の上限に達しました。"
        case let .dataInconsistency(reason):
            "データ整合性エラー: \(reason)"
        case let .migration(reason):
            "データ移行に失敗しました: \(reason)"
        case let .unknown(message):
            "エラーが発生しました: \(message)"
        }
    }

    public var severity: Severity {
        switch self {
        case .network(.disconnected): .minor
        case .network(.timeout): .moderate
        case .auth: .severe
        case .sync(.bufferFull): .moderate
        case .sync(.maxAttemptsExceeded): .severe
        case .validation: .moderate
        case .dataInconsistency: .critical
        case .migration: .critical
        case .unknown: .severe
        }
    }
}

public enum Severity: String, CaseIterable, Sendable {
    case minor       // バナー
    case moderate    // トースト
    case severe      // モーダル
    case critical    // 起動時ダイアログ
}

public enum NetworkErrorKind: String, Sendable {
    case disconnected
    case timeout
}

public enum AuthErrorKind: String, Sendable {
    case signInFailed
    case sessionExpired
}

public enum SyncErrorKind: String, Sendable {
    case bufferFull
    case maxAttemptsExceeded
}

public enum ValidationErrorKind: String, Sendable {
    case invalidScore
    case invalidLineup
    case duplicatePlayer
    case substitutionLimitExceeded
}
