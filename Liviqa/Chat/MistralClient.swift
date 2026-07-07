// MistralClient.swift — Enhanced (cloud) mode for the wellness-scope assistant.
// EU endpoint. Used ONLY when the user opts into cloud consent. The deterministic
// ChatGuard still runs before (input refusal) and after (output sanitise) every call,
// so the model can never move Liviqa across the non-MDSW line. v01 2026-06-09.
//
// PR-102 (launch audit): the Mistral key is DEBUG-only. Debug builds call the EU
// Mistral endpoint directly with the local gitignored key (LiviqaSecrets); Release
// builds carry NO key and route through the backend proxy — POST /ai/chat on the
// sovereign API base, authorised with the user's session bearer. The proxy holds
// the key server-side (route prepared in liviqa-backend in parallel).
import Foundation

enum MistralClient {
    static let endpoint = URL(string: "https://api.mistral.ai/v1/chat/completions")!
    static let model = "mistral-small-latest"   // EU-served; small/cheap for descriptive Q&A

    struct MistralError: Error { let message: String }

    #if DEBUG
    /// Enhanced (cloud) mode available — Debug: a local key is present.
    static var hasKey: Bool { !LiviqaSecrets.mistralAPIKey.isEmpty }
    #else
    /// Enhanced (cloud) mode available — Release: the sovereign backend proxy is
    /// reachable (no key ever ships in the binary).
    static var hasKey: Bool { proxyBaseURL != nil }

    /// API base for the /ai/chat proxy: the sovereign backend only. nil on
    /// mock/sandbox ⇒ cloud mode stays disabled and answers are on-device.
    private static var proxyBaseURL: URL? {
        if case .sovereign(let baseURL, _, _) = Config.backend { return baseURL }
        return nil
    }
    #endif

    /// One chat completion. Caller passes the fixed system prompt + a user message
    /// that already contains ONLY the user's own summarised numbers as context.
    static func complete(system: String, user: String) async throws -> String {
        #if DEBUG
        // Direct EU Mistral call with the local (gitignored, DEBUG-only) key.
        let key = LiviqaSecrets.mistralAPIKey
        guard !key.isEmpty else { throw MistralError(message: "no key") }
        var req = URLRequest(url: endpoint, timeoutInterval: 25)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model, "temperature": 0.2, "max_tokens": 320,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MistralError(message: "http \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        guard let content = (choices?.first?["message"] as? [String: Any])?["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw MistralError(message: "parse") }
        return content
        #else
        // Backend proxy call — the key never leaves the server. Contract:
        // POST {apiBase}/ai/chat  { "system": …, "user": … } → { "content": … },
        // authorised with the Keychained session bearer (NFR-SEC-01).
        guard let base = proxyBaseURL else { throw MistralError(message: "no proxy") }
        var req = URLRequest(url: base.appendingPathComponent("ai/chat"), timeoutInterval: 25)
        req.httpMethod = "POST"
        if let token = SessionTokenStore().load(), !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["system": system, "user": user]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MistralError(message: "http \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw MistralError(message: "parse") }
        return content
        #endif
    }
}
