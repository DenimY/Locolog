import Foundation
import AuthenticationServices
import Supabase

enum AuthState {
    case loading
    case signedOut
    case signedIn(userId: String, email: String?)
}

enum AuthError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        "Apple 인증 정보를 처리할 수 없습니다."
    }
}

@MainActor
final class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var authState: AuthState = .loading
    private var appleSignInContinuation: CheckedContinuation<ASAuthorization, Error>?

    var isSignedIn: Bool {
        if case .signedIn = authState { return true }
        return false
    }

    var currentUserEmail: String? {
        if case .signedIn(_, let email) = authState { return email }
        return nil
    }

    // MARK: - Session Restore

    func restoreSession() {
        if let session = supabase.auth.currentSession {
            authState = .signedIn(userId: session.user.id.uuidString, email: session.user.email)
        } else {
            authState = .signedOut
        }
    }

    // MARK: - Apple Sign-In

    func signInWithApple() async throws {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorization = try await withCheckedThrowingContinuation { cont in
            self.appleSignInContinuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
        authState = .signedIn(userId: session.user.id.uuidString, email: session.user.email)
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
        authState = .signedOut
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            self.appleSignInContinuation?.resume(returning: authorization)
            self.appleSignInContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.appleSignInContinuation?.resume(throwing: error)
            self.appleSignInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            #if os(macOS)
            return NSApp.keyWindow ?? NSWindow()
            #else
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first(where: \.isKeyWindow) ?? UIWindow()
            #endif
        }
    }
}
