//
//  KeychainStore.swift
//  SwiftBaseClassWAC
//
//  Secure storage for small secrets (auth tokens, etc.) backed by the
//  iOS Keychain. Prefer this over UserDefaults for anything sensitive.
//

import Foundation
import Security

protocol SecureStore: Sendable {
    func string(for key: String) -> String?
    func set(_ value: String?, for key: String)
    func removeAll()
}

struct KeychainStore: SecureStore {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "SwiftBaseClassWAC") {
        self.service = service
    }

    func string(for key: String) -> String? {
        data(for: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    func set(_ value: String?, for key: String) {
        guard let value, let data = value.data(using: .utf8) else {
            delete(key)
            return
        }
        var query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func removeAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private

    private func data(for key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
