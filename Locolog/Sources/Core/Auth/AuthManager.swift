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
    case callbackFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "인증 정보를 처리할 수 없습니다."
        case .callbackFailed:    return "로그인 콜백을 처리할 수 없습니다."
        }
    }
}

@MainActor
final class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var authState: AuthState = .loading

    private var appleSignInContinuation: CheckedContinuation<ASAuthorization, Error>?
    private var webAuthSession: ASWebAuthenticationSession?

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

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        let redirectURL = URL(string: "com.locolog.app://auth-callback")!

        let oauthURL = try await supabase.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: redirectURL
        )

        let callbackURL = try await performWebAuth(url: oauthURL, callbackScheme: "com.locolog.app")

        let session = try await supabase.auth.session(from: callbackURL)
        authState = .signedIn(userId: session.user.id.uuidString, email: session.user.email)
    }

    // ASWebAuthenticationSession 실행 후 콜백 URL 반환
    private func performWebAuth(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.webAuthSession = nil
                if let error {
                    cont.resume(throwing: error)
                } else if let callbackURL {
                    cont.resume(returning: callbackURL)
                } else {
                    cont.resume(throwing: AuthError.callbackFailed)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
        authState = .signedOut
    }
}

// MARK: - ASAuthorizationControllerDelegate (Apple Sign-In)

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

// MARK: - Presentation Context (Apple Sign-In + Google Web Auth)

extension AuthManager: ASAuthorizationControllerPresentationContextProviding,
                       ASWebAuthenticationPresentationContextProviding {

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor()
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor()
    }

    private nonisolated func anchor() -> ASPresentationAnchor {
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
