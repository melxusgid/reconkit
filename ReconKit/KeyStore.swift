//
//  KeyStore.swift
//  ReconKit
//
//  Stores user-supplied API keys in the macOS Keychain. Keys never leave the
//  machine and aren't bundled in the app — each user brings their own.
//

import Foundation
import Security

enum KeyStore {
    static let virusTotal = "virustotal"

    private static let service = "com.reconkit.apikeys"

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    static func set(_ value: String?, for account: String) {
        // Remove any existing item first.
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)

        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty,
              let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func has(_ account: String) -> Bool { get(account) != nil }
}
