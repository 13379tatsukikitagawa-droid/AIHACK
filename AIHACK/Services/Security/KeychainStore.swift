import Foundation
import Security

/// 永続化が必要な機密性の高い設定・識別子（例: 将来ユーザー識別子を導入する場合など）を
/// UserDefaultsではなくKeychainへ保存するための薄いラッパー。現時点でアプリ本体は
/// アカウント機能を持たないため未使用だが、その種の値が増えた際にUserDefaultsへ
/// 平文保存されることを防ぐための受け皿として用意する。
///
/// kSecAttrAccessibleWhenUnlockedThisDeviceOnly を指定し、端末ロック解除中のみアクセス可能・
/// iCloudキーチェーン同期や他端末への引き継ぎも行わない、最も保守的な可用性ポリシーとする。
enum KeychainStore {
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case unexpectedData
    }

    private static let service = "com.tatsukikitagawa.AIHACK"

    static func set(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        // 既存値がある場合は更新、無ければ新規追加する（upsert）。
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery(forKey: key) as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    static func string(forKey key: String) throws -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 値をKeychainから完全に削除する。メモリ上の一時変数はこの呼び出しの前後で
    /// 呼び出し側が保持しないようにすること（このメソッド自体はKeychain内のエントリのみを消去する）。
    static func remove(forKey key: String) throws {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
