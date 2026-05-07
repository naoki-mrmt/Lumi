// SupabaseAuthClient — Supabase Auth の抽象化

import Foundation

public struct AuthSession: Equatable, Sendable {
    public let userId: UUID
    public let email: String?
    public let accessToken: String

    public init(userId: UUID, email: String? = nil, accessToken: String) {
        self.userId = userId
        self.email = email
        self.accessToken = accessToken
    }
}

public protocol SupabaseAuthClient: Sendable {
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession
    func signOut() async throws
    func currentSession() async -> AuthSession?
    /// アカウント削除 (Edge Function "delete-account" を service_role 権限で呼び出す前提)。
    /// 関連 RLS データは ON DELETE CASCADE で連鎖削除される。
    func deleteAccount() async throws
}

public final class MockSupabaseAuthClient: SupabaseAuthClient, @unchecked Sendable {
    private var session: AuthSession?
    public var shouldFail: Bool = false
    public private(set) var deletedAccount: Bool = false

    public init(initial: AuthSession? = nil) {
        self.session = initial
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        if shouldFail { throw AppleSignInError.missingIdentityToken }
        let s = AuthSession(userId: UUID(), email: "mock@example.com", accessToken: "MOCK_ACCESS_TOKEN")
        session = s
        return s
    }

    public func signOut() async throws {
        session = nil
    }

    public func currentSession() async -> AuthSession? {
        session
    }

    public func deleteAccount() async throws {
        deletedAccount = true
        session = nil
    }
}
