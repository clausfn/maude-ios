// MistralClient.swift — Enhanced (cloud) mode for the wellness-scope assistant.
// EU endpoint. Used ONLY when the user opts into cloud consent. The deterministic
// ChatGuard still runs before (input refusal) and after (output sanitise) every call,
// so the model can never move Liviqa across the non-MDSW line. v01 2026-06-09.
import Foundation

enum MistralClient {
    static let endpoint = URL(string: "https://api.mistral.ai/v1/chat/completions")!
    static let model = "mistral-small-latest"   // EU-served; small/cheap for descriptive Q&A

    struct MistralError: Error { let message: String }

    static var hasKey: Bool { !LiviqaSecrets.mistralAPIKey.isEmpty }

    /// One chat completion. Caller passes the fixed system prompt + a user message
    /// that already contains ONLY the user's own summarised numbers as context.
    static func complete(system: String, user: String) async throws -> String {
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
    }
}
