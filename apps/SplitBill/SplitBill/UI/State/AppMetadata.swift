import Foundation

/// Value type providing application metadata, version information, and legal/support URLs
/// required for App Store compliance (Apple Guidelines 1.5 and 5.1.1(i)).
struct AppMetadata: Sendable, Equatable {

    // MARK: - Properties

    let appName: String
    let marketingVersion: String
    let buildNumber: String
    let privacyPolicyURL: URL
    let supportURL: URL

    // MARK: - Computed Properties

    var formattedVersion: String {
        "Versión \(marketingVersion) (\(buildNumber))"
    }

    // MARK: - Fallback Static URLs

    static let defaultPrivacyURL: URL = {
        guard let url = URL(string: "https://github.com/gerar-18/split-bill/blob/main/docs/legal/privacy.md") else {
            preconditionFailure("Invalid default privacy URL")
        }
        return url
    }()

    static let defaultSupportURL: URL = {
        guard let url = URL(string: "https://github.com/gerar-18/split-bill/blob/main/docs/legal/support.md") else {
            preconditionFailure("Invalid default support URL")
        }
        return url
    }()

    // MARK: - Factory

    static func current(bundle: Bundle = .main) -> AppMetadata {
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "SplitBill"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        return AppMetadata(
            appName: name,
            marketingVersion: version,
            buildNumber: build,
            privacyPolicyURL: defaultPrivacyURL,
            supportURL: defaultSupportURL
        )
    }
}
