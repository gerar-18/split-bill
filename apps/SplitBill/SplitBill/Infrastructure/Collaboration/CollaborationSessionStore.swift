import Foundation
import Security

/// Persists ephemeral capability tokens and UGC moderation preferences (hidden images & blocked sessions).
nonisolated protocol CollaborationStateStoring: Sendable {
    func saveSessionToken(_ token: String, forShareCode code: String)
    func loadSessionToken(forShareCode code: String) -> String?
    func deleteSessionToken(forShareCode code: String)

    func isImageHidden(forSessionID sessionID: String) -> Bool
    func setImageHidden(_ hidden: Bool, forSessionID sessionID: String)

    func isSessionBlocked(sessionIDOrCode: String) -> Bool
    func blockSession(sessionIDOrCode: String)
}

/// Production Keychain + UserDefaults persistence for collaborative sessions.
/// Thread-safety is guaranteed because `SecItem*` and `UserDefaults` are documented thread-safe by Apple.
nonisolated final class KeychainCollaborationStateStore: CollaborationStateStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keychainService = "com.gerar18.SplitBill.collaboration.tokens"
    private let hiddenImagesKey = "splitbill.collab.hiddenImages"
    private let blockedSessionsKey = "splitbill.collab.blockedSessions"

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveSessionToken(_ token: String, forShareCode code: String) {
        guard let data = token.data(using: .utf8) else { return }
        let account = code.uppercased()
        deleteSessionToken(forShareCode: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func loadSessionToken(forShareCode code: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: code.uppercased(),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteSessionToken(forShareCode code: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: code.uppercased()
        ]
        SecItemDelete(query as CFDictionary)
    }

    func isImageHidden(forSessionID sessionID: String) -> Bool {
        let list = defaults.stringArray(forKey: hiddenImagesKey) ?? []
        return list.contains(sessionID)
    }

    func setImageHidden(_ hidden: Bool, forSessionID sessionID: String) {
        var set = Set(defaults.stringArray(forKey: hiddenImagesKey) ?? [])
        if hidden {
            set.insert(sessionID)
        } else {
            set.remove(sessionID)
        }
        defaults.set(Array(set), forKey: hiddenImagesKey)
    }

    func isSessionBlocked(sessionIDOrCode: String) -> Bool {
        let list = defaults.stringArray(forKey: blockedSessionsKey) ?? []
        return list.contains(sessionIDOrCode.uppercased())
    }

    func blockSession(sessionIDOrCode: String) {
        var set = Set(defaults.stringArray(forKey: blockedSessionsKey) ?? [])
        set.insert(sessionIDOrCode.uppercased())
        defaults.set(Array(set), forKey: blockedSessionsKey)
    }
}

/// Deterministic thread-safe in-memory store for unit tests.
nonisolated final class InMemoryCollaborationStateStore: CollaborationStateStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [String: String] = [:]
    private var hiddenImages: Set<String> = []
    private var blocked: Set<String> = []

    func saveSessionToken(_ token: String, forShareCode code: String) {
        lock.withLock { tokens[code.uppercased()] = token }
    }

    func loadSessionToken(forShareCode code: String) -> String? {
        lock.withLock { tokens[code.uppercased()] }
    }

    func deleteSessionToken(forShareCode code: String) {
        _ = lock.withLock { tokens.removeValue(forKey: code.uppercased()) }
    }

    func isImageHidden(forSessionID sessionID: String) -> Bool {
        lock.withLock { hiddenImages.contains(sessionID) }
    }

    func setImageHidden(_ hidden: Bool, forSessionID sessionID: String) {
        lock.withLock {
            if hidden {
                _ = hiddenImages.insert(sessionID)
            } else {
                _ = hiddenImages.remove(sessionID)
            }
        }
    }

    func isSessionBlocked(sessionIDOrCode: String) -> Bool {
        lock.withLock { blocked.contains(sessionIDOrCode.uppercased()) }
    }

    func blockSession(sessionIDOrCode: String) {
        _ = lock.withLock { blocked.insert(sessionIDOrCode.uppercased()) }
    }
}
