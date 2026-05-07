// LiveSupabaseAuthClient — Supabase SDK 経由の認証

import Foundation
import Supabase

public final class LiveSupabaseAuthClient: SupabaseAuthClient, @unchecked Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        return AuthSession(
            userId: session.user.id,
            email: session.user.email,
            accessToken: session.accessToken
        )
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }

    public func currentSession() async -> AuthSession? {
        guard let session = try? await client.auth.session else { return nil }
        return AuthSession(
            userId: session.user.id,
            email: session.user.email,
            accessToken: session.accessToken
        )
    }
}
