import Foundation
import Security

struct BinanceCredentials: Codable, Sendable {
    let apiKey: String
    let secretKey: Data

    private static let service = "com.chenwuai.btcwatcher.binance"
    private static let account = "credentials"

    enum Failure: Error {
        case missingCredentials
        case invalidCredentials
        case read(OSStatus)
        case save(OSStatus)
    }

    static func load() throws -> Self {
        if let credentials = try loadSaved() { return credentials }

        let apiKeyQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "api-key"
        ]
        let secretKeyQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrLabel: service,
            kSecAttrAccount: "secret-key"
        ]
        guard let apiKeyData = try read(apiKeyQuery), let secretKey = try read(secretKeyQuery) else {
            throw Failure.missingCredentials
        }
        guard let apiKey = String(data: apiKeyData, encoding: .utf8), !apiKey.isEmpty else {
            throw Failure.invalidCredentials
        }

        let credentials = Self(apiKey: apiKey, secretKey: secretKey)
        // An account saved while migration was in progress takes precedence.
        if let data = try? JSONEncoder().encode(credentials), add(data) == errSecDuplicateItem {
            return try loadSaved() ?? credentials
        }
        return credentials
    }

    func save() throws {
        let data = try JSONEncoder().encode(self)
        let attributes = [kSecValueData: data] as CFDictionary
        var status = Self.add(data)
        if status == errSecDuplicateItem {
            status = SecItemUpdate(Self.savedQuery as CFDictionary, attributes)
        }
        guard status == errSecSuccess else { throw Failure.save(status) }
    }

    private static var savedQuery: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    private static func add(_ data: Data) -> OSStatus {
        var item = savedQuery
        item[kSecAttrLabel] = "\(service).\(account)"
        item[kSecValueData] = data
        return SecItemAdd(item as CFDictionary, nil)
    }

    private static func loadSaved() throws -> Self? {
        guard let data = try read(savedQuery) else { return nil }
        guard let credentials = try? JSONDecoder().decode(Self.self, from: data),
              !credentials.apiKey.isEmpty, !credentials.secretKey.isEmpty else {
            throw Failure.invalidCredentials
        }
        return credentials
    }

    private static func read(_ attributes: [CFString: Any]) throws -> Data? {
        var query = attributes
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure.read(status) }
        guard let data = item as? Data, !data.isEmpty else { throw Failure.invalidCredentials }
        return data
    }
}
