import Foundation
import Security

enum KeychainManager {
    private static let service = "com.locolog.app"

    static func save(_ value: String, forKey key: String) {
        let base: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: service
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var query = base
        query[kSecValueData] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: service,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
