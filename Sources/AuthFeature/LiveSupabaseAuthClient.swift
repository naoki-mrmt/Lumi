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

    /// Edge Function `delete-account` を呼び出してユーザを削除する。
    /// 関数側は service_role キーで `auth.admin.deleteUser(userId)` を実行する想定。
    /// supabase/functions/delete-account/index.ts を別途デプロイ要。
    ///
    /// supabase-swift FunctionsClient は options.method が nil の場合 POST を既定にする
    /// (FunctionsClient.swift: `FunctionInvokeOptions.httpMethod(options.method) ?? .post`)
    /// ため、明示せず呼び出して問題ない。
    public func deleteAccount() async throws {
        _ = try await client.functions.invoke("delete-account")
        try? await client.auth.signOut()
    }
}
