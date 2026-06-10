import Foundation
import Security

enum KeychainHelper {
    /// Namespaces our items so they can't collide with entries from libraries.
    private static let service = "app.serenity.keychain"

    /// Base query identifying an item; save/load/delete all build on it.
    private static func baseQuery(forKey key: String) -> [CFString: Any] {
        [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
    }

    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        var query = baseQuery(forKey: key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData] = data
        // Readable only while the device is unlocked, never migrated via backups.
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    }
}
