// SupabaseAuthClient.swift — Supabase Auth (GoTrue) client for the citizen app.
// Auth = self-hosted GoTrue in the EU (Scaleway) — sovereign + $0 license
// (NFR-SEC-07); NOT Supabase Cloud (US), NOT Ory (custom-domain cost). The app
// signs in here, then presents the Supabase ACCESS TOKEN (JWT) as
// `Authorization: Bearer <jwt>` to the Liviqa backend, which verifies the JWT
// (jose, HS256/JWKS) and maps to the account by email. See docs/Auth_Supabase_v01.md.
//
// GoTrue endpoints used:
//   POST {base}/auth/v1/token?grant_type=password       { email, password }
//   POST {base}/auth/v1/token?grant_type=id_token        { provider:"apple", id_token, nonce }
//   POST {base}/auth/v1/token?grant_type=refresh_token   { refresh_token }  → fresh session
//   POST {base}/auth/v1/recover             { email }     → password-reset e-mail
//   GET  {base}/auth/v1/user            (Bearer)     → current user
//   POST {base}/auth/v1/logout          (Bearer)
import Foundation

/// Resolved Supabase session: the bearer (access token) + who it belongs to.
struct SupabaseSessionResult: Equatable, Sendable {
    let accessToken: String
    let userID: String
    let email: String?
    let refreshToken: String?
}

/// Signup accepted but session withheld: the GoTrue deployment has confirmation
/// e-mails ON, so the citizen must click the link before signing in. Typed
/// separately from `SupabaseError` (shared enum, not owned here) so the UI can
/// show a calm "check your inbox" instead of the misleading "not signed in".
struct EmailConfirmationPending: LocalizedError, Equatable {
    static let message = String(localized: "Almost there — check your email to confirm your account, then sign in.")
    var errorDescription: String? { Self.message }
}

final class SupabaseAuthClient: @unchecked Sendable {

    private let baseURL: URL
    /// Optional `apikey` header — needed when GoTrue sits behind the Supabase
    /// gateway (Kong); bare self-hosted GoTrue doesn't require it.
    private let apiKey: String?
    private let session: URLSession

    /// Default session with sane timeouts (URLSession.shared waits 60 s per
    /// request) — a dead network should fail fast into friendly copy.
    static let defaultSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 30
        return URLSession(configuration: c)
    }()

    init(baseURL: URL, apiKey: String? = nil, session: URLSession = SupabaseAuthClient.defaultSession) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Email/password

    func login(email: String, password: String) async throws -> SupabaseSessionResult {
        let (data, status) = try await post("/auth/v1/token?grant_type=password",
                                            body: Self.passwordBody(email: email, password: password))
        switch status {
        case 200:
            guard let r = Self.parseTokenResponse(data) else {
                throw SupabaseError.serverError("Supabase: malformed token response.")
            }
            return r
        case 400, 401, 403:
            throw SupabaseError.invalidCredentials
        default:
            throw SupabaseError.serverError("Supabase login failed (HTTP \(status)).")
        }
    }

    /// POST {base}/auth/v1/signup — create a user. With GOTRUE_MAILER_AUTOCONFIRM
    /// the response carries a full session (access_token); if a deployment ever
    /// turns confirmation e-mails on, the 200 comes back WITHOUT a token and the
    /// caller must surface a "confirm your email" state (EmailConfirmationPending).
    func signup(email: String, password: String) async throws -> SupabaseSessionResult {
        let (data, status) = try await post("/auth/v1/signup",
                                            body: Self.passwordBody(email: email, password: password))
        switch status {
        case 200:
            if let r = Self.parseTokenResponse(data) { return r }
            // 200 without a token = confirmation-pending deployment — a distinct
            // typed outcome, NOT an error ("You are not signed in." misleads here).
            throw EmailConfirmationPending()
        case 400, 422:
            throw Self.mapSignupError(data)
        default:
            throw SupabaseError.serverError("Supabase signup failed (HTTP \(status)).")
        }
    }

    /// POST {base}/auth/v1/recover — ask GoTrue to e-mail a password-reset link
    /// (standard template). 200 = accepted even for unknown emails (no account
    /// enumeration), so the UI copy must stay conditional ("if an account exists…").
    func recover(email: String) async throws {
        let (_, status) = try await post("/auth/v1/recover", body: Self.emailBody(email))
        switch status {
        case 200...299:
            return
        case 429:
            throw SupabaseError.serverError("Too many reset requests. Wait a minute, then try again.")
        default:
            throw SupabaseError.serverError("We couldn't send the reset email right now. Try again in a moment.")
        }
    }

    /// POST {base}/auth/v1/token?grant_type=refresh_token — trade the stored
    /// refresh token for a fresh session (GoTrue rotates the refresh token).
    func refresh(refreshToken: String) async throws -> SupabaseSessionResult {
        let (data, status) = try await post("/auth/v1/token?grant_type=refresh_token",
                                            body: Self.refreshBody(refreshToken: refreshToken))
        switch status {
        case 200:
            guard let r = Self.parseTokenResponse(data) else {
                throw SupabaseError.serverError("Supabase: malformed refresh response.")
            }
            return r
        case 400, 401, 403:
            throw SupabaseError.notSignedIn   // refresh token expired/revoked → real sign-out
        default:
            throw SupabaseError.serverError("Supabase refresh failed (HTTP \(status)).")
        }
    }

    /// GoTrue signup rejections → typed errors (pure → unit-testable).
    /// Shapes seen across GoTrue versions: {"msg": …} / {"message": …} /
    /// {"error_description": …} / {"error_code":"user_already_exists"}.
    static func mapSignupError(_ data: Data) -> SupabaseError {
        let o = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let code = (o["error_code"] as? String ?? "").lowercased()
        let msg = (o["msg"] as? String ?? o["message"] as? String ?? o["error_description"] as? String ?? "")
        let lower = msg.lowercased()
        if code.contains("already") || lower.contains("already registered") || lower.contains("already exists") {
            return .emailTaken
        }
        if code.contains("weak_password") || lower.contains("password") {
            return .weakPassword(msg)
        }
        return .serverError(msg.isEmpty ? "Signup failed." : msg)
    }

    // MARK: - Sign in with Apple (native id_token grant)

    func loginWithApple(idToken: String, nonce: String) async throws -> SupabaseSessionResult {
        let (data, status) = try await post("/auth/v1/token?grant_type=id_token",
                                            body: Self.appleGrantBody(idToken: idToken, nonce: nonce))
        switch status {
        case 200:
            guard let r = Self.parseTokenResponse(data) else {
                throw SupabaseError.serverError("Supabase: malformed Apple token response.")
            }
            return r
        case 400, 401, 403:
            throw SupabaseError.invalidCredentials
        default:
            throw SupabaseError.serverError("Supabase Apple login failed (HTTP \(status)).")
        }
    }

    // MARK: - Session check / logout

    func user(token: String) async throws -> SupabaseSessionResult {
        let (data, status) = try await get("/auth/v1/user", bearer: token)
        guard status == 200, let r = Self.parseUser(data, token: token) else {
            throw SupabaseError.notSignedIn
        }
        return r
    }

    func logout(token: String) async throws {
        _ = try? await post("/auth/v1/logout", body: Data("{}".utf8), bearer: token)
    }

    // MARK: - Bodies + parsing (pure → unit-testable without networking)

    static func passwordBody(email: String, password: String) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["email": email, "password": password])) ?? Data()
    }

    static func emailBody(_ email: String) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["email": email])) ?? Data()
    }

    static func refreshBody(refreshToken: String) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])) ?? Data()
    }

    /// GoTrue native id_token grant. `nonce` is the RAW nonce; GoTrue checks it
    /// against the Apple token's hashed nonce. Omitted when empty.
    static func appleGrantBody(idToken: String, nonce: String) -> Data {
        var payload: [String: Any] = ["provider": "apple", "id_token": idToken]
        if !nonce.isEmpty { payload["nonce"] = nonce }
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    static func parseTokenResponse(_ data: Data) -> SupabaseSessionResult? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = o["access_token"] as? String else { return nil }
        let user = o["user"] as? [String: Any]
        let id = (user?["id"] as? String) ?? ""
        let email = user?["email"] as? String
        return SupabaseSessionResult(accessToken: token, userID: id, email: email,
                                     refreshToken: o["refresh_token"] as? String)
    }

    static func parseUser(_ data: Data, token: String) -> SupabaseSessionResult? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = o["id"] as? String else { return nil }
        return SupabaseSessionResult(accessToken: token, userID: id,
                                     email: o["email"] as? String, refreshToken: nil)
    }

    // MARK: - HTTP

    private func url(for path: String) -> URL { URL(string: path, relativeTo: baseURL) ?? baseURL }

    private func get(_ path: String, bearer: String?) async throws -> (Data, Int) {
        try await send(path, method: "GET", body: nil, bearer: bearer)
    }
    @discardableResult
    private func post(_ path: String, body: Data, bearer: String? = nil) async throws -> (Data, Int) {
        try await send(path, method: "POST", body: body, bearer: bearer)
    }

    private func send(_ path: String, method: String, body: Data?, bearer: String?) async throws -> (Data, Int) {
        var req = URLRequest(url: url(for: path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey { req.setValue(apiKey, forHTTPHeaderField: "apikey") }
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw SupabaseError.serverError(error.localizedDescription) }
        return (data, (response as? HTTPURLResponse)?.statusCode ?? -1)
    }
}
