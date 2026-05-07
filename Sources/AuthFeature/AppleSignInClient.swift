// AppleSignInClient — Sign in with Apple フローの抽象化

import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

public struct AppleCredentials: Equatable, Sendable {
    public let userId: String
    public let identityToken: String
    public let nonce: String
    public let email: String?
    public let fullName: PersonNameComponents?

    public init(userId: String, identityToken: String, nonce: String, email: String? = nil, fullName: PersonNameComponents? = nil) {
        self.userId = userId
        self.identityToken = identityToken
        self.nonce = nonce
        self.email = email
        self.fullName = fullName
    }
}

public protocol AppleSignInClient: Sendable {
    func authorize() async throws -> AppleCredentials
}

public enum AppleSignInError: Error, Equatable, Sendable {
    case unavailable
    case userCancelled
    case missingIdentityToken
}

#if canImport(CryptoKit)
public enum NonceGenerator {
    public static func random(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in
            charset[Int(rng.next() % UInt64(charset.count))]
        })
    }

    public static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
#endif

public struct MockAppleSignInClient: AppleSignInClient {
    public var credentials: AppleCredentials
    public var error: AppleSignInError?

    public init(credentials: AppleCredentials = AppleCredentials(userId: "MOCK_USER", identityToken: "MOCK_TOKEN", nonce: "MOCK_NONCE", email: "mock@example.com")) {
        self.credentials = credentials
    }

    public func authorize() async throws -> AppleCredentials {
        if let e = error { throw e }
        return credentials
    }
}
