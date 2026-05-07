// LiveAppleSignInClient — ASAuthorizationController 連携の本番実装
//
// iOS 限定。macOS テスト時はコンパイルされない。

import Foundation
#if canImport(AuthenticationServices) && canImport(UIKit)
import AuthenticationServices
import CryptoKit
import UIKit

public final class LiveAppleSignInClient: NSObject, AppleSignInClient, @unchecked Sendable {
    public override init() { super.init() }

    public func authorize() async throws -> AppleCredentials {
        let nonce = NonceGenerator.random()
        let hashedNonce = NonceGenerator.sha256(nonce)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppleCredentials, Error>) in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AuthDelegate(rawNonce: nonce, continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            // delegate を保持
            objc_setAssociatedObject(controller, AuthDelegate.associationKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            controller.performRequests()
        }
    }
}

private final class AuthDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    /// `objc_setAssociatedObject` に渡すユニークなキー。
    /// 1 byte の定数を 1 度だけ allocate して静的に保持する (allocate は init 時の 1 回のみ、leak とは別)。
    nonisolated(unsafe) static let associationKey: UnsafeRawPointer = {
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        p.pointee = 0
        return UnsafeRawPointer(p)
    }()
    let rawNonce: String
    let continuation: CheckedContinuation<AppleCredentials, Error>
    init(rawNonce: String, continuation: CheckedContinuation<AppleCredentials, Error>) {
        self.rawNonce = rawNonce
        self.continuation = continuation
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8)
        else {
            continuation.resume(throwing: AppleSignInError.missingIdentityToken)
            return
        }
        let creds = AppleCredentials(
            userId: credential.user,
            identityToken: token,
            nonce: rawNonce,
            email: credential.email,
            fullName: credential.fullName
        )
        continuation.resume(returning: creds)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            continuation.resume(throwing: AppleSignInError.userCancelled)
        } else {
            continuation.resume(throwing: error)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
#endif
