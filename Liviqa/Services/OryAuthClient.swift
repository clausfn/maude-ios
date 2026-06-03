// OryAuthClient.swift — Ory Network (Kratos) NATIVE auth for the citizen app.
// The sovereign backend validates an Ory session token presented as
// `Authorization: Bearer <token>` (openapi.yaml: "prod: Ory session token").
// This client runs the native (API) login flow to obtain that token.
//
// FR-SHARE-02 / NFR-SEC-07 auth · Ory native flow:
//   1. GET  {ory}/self-service/login/api        → flow { id, ui.action }
//   2. POST {ui.action}  { method:"password", identifier, password }
//                                                → { session_token, session.identity }
//   3. GET  {ory}/sessions/whoami  (Bearer)     → identity (session check)
//   4. POST {ory}/self-service/logout/api  { session_token }
import Foundation

/// Resolved Ory session: the bearer token + who it belongs to.
struct OrySessionResult: Equatable, Sendable {
    let token: String
    let identityID: String
    let email: String?
}

final class OryAuthClient: @unchecked Sendable {

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Native email/password login

    func login(email: String, password: String) async throws -> OrySessionResult {
        // 1) Initialise a native login flow.
        let flowData = try await send(path: "/self-service/login/api", method: "GET", body: nil)
        guard let flow = Self.parseFlow(flowData) else {
            throw SupabaseError.serverError("Ory: could not start login flow.")
        }
        // 2) Submit credentials to the flow's action URL.
        let body = try JSONSerialization.data(withJSONObject: [
            "method": "password",
            "identifier": email,
            "password": password,
        ])
        let (data, status) = try await sendRaw(urlString: flow.action, method: "POST", body: body)
        switch status {
        case 200:
            guard let result = Self.parseLoginSuccess(data) else {
                throw SupabaseError.serverError("Ory: malformed login response.")
            }
            return result
        case 400:
            // Flow returned with validation messages → bad credentials.
            throw SupabaseError.invalidCredentials
        case 401, 403:
            throw SupabaseError.invalidCredentials
        default:
            throw SupabaseError.serverError("Ory login failed (HTTP \(status)).")
        }
    }

    // MARK: - Session check

    func whoami(token: String) async throws -> OrySessionResult {
        let data = try await send(path: "/sessions/whoami", method: "GET", body: nil, bearer: token)
        guard let result = Self.parseWhoami(data, token: token) else {
            throw SupabaseError.notSignedIn
        }
        return result
    }

    // MARK: - Logout

    func logout(token: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["session_token": token])
        _ = try? await sendRaw(urlString: url(for: "/self-service/logout/api").absoluteString,
                               method: "POST", body: body)
    }

    // MARK: - Parsing (pure → unit-testable without networking)

    struct Flow: Equatable { let id: String; let action: String }

    static func parseFlow(_ data: Data) -> Flow? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = o["id"] as? String,
              let ui = o["ui"] as? [String: Any],
              let action = ui["action"] as? String else { return nil }
        return Flow(id: id, action: action)
    }

    static func parseLoginSuccess(_ data: Data) -> OrySessionResult? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = o["session_token"] as? String else { return nil }
        let identity = (o["session"] as? [String: Any])?["identity"] as? [String: Any]
        let id = (identity?["id"] as? String) ?? ""
        let email = (identity?["traits"] as? [String: Any])?["email"] as? String
        return OrySessionResult(token: token, identityID: id, email: email)
    }

    static func parseWhoami(_ data: Data, token: String) -> OrySessionResult? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let identity = o["identity"] as? [String: Any]
        guard let id = identity?["id"] as? String else { return nil }
        let email = (identity?["traits"] as? [String: Any])?["email"] as? String
        return OrySessionResult(token: token, identityID: id, email: email)
    }

    // MARK: - HTTP

    private func url(for path: String) -> URL {
        URL(string: path, relativeTo: baseURL) ?? baseURL
    }

    private func send(path: String, method: String, body: Data?, bearer: String? = nil) async throws -> Data {
        let (data, status) = try await sendRaw(urlString: url(for: path).absoluteString,
                                               method: method, body: body, bearer: bearer)
        guard (200...299).contains(status) else {
            if status == 401 || status == 403 { throw SupabaseError.notSignedIn }
            throw SupabaseError.serverError("Ory HTTP \(status)")
        }
        return data
    }

    private func sendRaw(urlString: String, method: String, body: Data?, bearer: String? = nil) async throws -> (Data, Int) {
        guard let url = URL(string: urlString) else { throw SupabaseError.serverError("Ory: bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) }
        catch { throw SupabaseError.serverError(error.localizedDescription) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        return (data, status)
    }
}
