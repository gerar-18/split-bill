import Foundation

/// Protocolo que define el almacenamiento de consentimiento para el procesamiento de datos con IA (Apple Guideline 5.1.2(i)).
nonisolated protocol AIConsentStoring: Sendable {
    var hasGrantedConsent: Bool { get }
    var consentTimestamp: Date? { get }
    func grantConsent()
    func revokeConsent()
}

/// Implementación persistente respaldada por UserDefaults.
nonisolated final class UserDefaultsAIConsentStore: AIConsentStoring, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let grantedKey = "SplitBill.AIConsentGranted"
    private let dateKey = "SplitBill.AIConsentDate"

    nonisolated init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var hasGrantedConsent: Bool {
        userDefaults.bool(forKey: grantedKey)
    }

    var consentTimestamp: Date? {
        guard hasGrantedConsent else { return nil }
        return userDefaults.object(forKey: dateKey) as? Date
    }

    func grantConsent() {
        userDefaults.set(true, forKey: grantedKey)
        userDefaults.set(Date(), forKey: dateKey)
    }

    func revokeConsent() {
        userDefaults.set(false, forKey: grantedKey)
        userDefaults.removeObject(forKey: dateKey)
    }
}

/// Implementación en memoria thread-safe para pruebas unitarias aisladas.
nonisolated final class InMemoryAIConsentStore: AIConsentStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _hasGrantedConsent: Bool
    private var _consentTimestamp: Date?

    nonisolated init(hasGrantedConsent: Bool = false, consentTimestamp: Date? = nil) {
        self._hasGrantedConsent = hasGrantedConsent
        self._consentTimestamp = consentTimestamp
    }

    var hasGrantedConsent: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasGrantedConsent
    }

    var consentTimestamp: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _consentTimestamp
    }

    func grantConsent() {
        lock.lock()
        defer { lock.unlock() }
        _hasGrantedConsent = true
        _consentTimestamp = Date()
    }

    func revokeConsent() {
        lock.lock()
        defer { lock.unlock() }
        _hasGrantedConsent = false
        _consentTimestamp = nil
    }
}
