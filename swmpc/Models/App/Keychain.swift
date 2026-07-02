//
//  Keychain.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2026.
//

import Foundation
import Security

/// Minimal wrapper around the Keychain for storing secret strings such as
/// provider API tokens.
///
/// Uses the data-protection keychain for consistent behaviour across macOS and
/// iOS, scoped to a single service so items never collide with other apps.
nonisolated enum Keychain {
    private static let service = "\(Bundle.main.bundleIdentifier ?? "swmpc").intelligence"

    /// Reads the string stored for the given account, or `nil` when absent.
    static func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    /// Stores `value` for the given account, or deletes the item when `value`
    /// is `nil` or empty.
    static func set(_ value: String?, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]

        guard let value, !value.isEmpty else {
            SecItemDelete(base as CFDictionary)
            return
        }

        let data = Data(value.utf8)

        let status = SecItemUpdate(
            base as CFDictionary,
            [kSecValueData as String: data] as CFDictionary,
        )

        if status == errSecItemNotFound {
            var addQuery = base
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
