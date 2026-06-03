// SessionTokenStore.swift — Keychain persistence for the auth access token
// (NFR-SEC-01 / FR-AUTH-03: auth tokens live in the Keychain, never in
// UserDefaults or plain files). The token is the Supabase (GoTrue) access-token
// JWT presented to the backend as a bearer.
//
// A small generic-password store, isolated from `KeyVault` (which manages the
// Secure-Enclave data key). Device-only, available after first unlock. Pure
// Foundation + Security; no SwiftUI/SwiftData.
import Foundation
import Security

public struct SessionTokenStore: Sendable {
    private let service: String
    private let account: String

    public init(service: String = "io.liviqa.session", account: String = "auth.access_token") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Persist (or replace) the token. A nil/empty token clears the slot.
    public func save(_ token: String?) {
        guard let token, !token.isEmpty, let data = token.data(using: .utf8) else {
            clear(); return
        }
        clear()
        var q = baseQuery
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    /// Load the token, or nil if absent.
    public func load() -> String? {
        var q = baseQuery
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
