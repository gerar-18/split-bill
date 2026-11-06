import Foundation
import Testing
@testable import SplitBill

@Suite("App Store Bundle & Privacy Compliance Tests")
struct AppBundleComplianceTests {

    private var appBundle: Bundle {
        // When running unit tests with TEST_HOST, Bundle.main is the SplitBill.app bundle.
        // If not, fall back to the bundle containing MyApp.
        if Bundle.main.bundleIdentifier?.contains("SplitBillTests") == false {
            return Bundle.main
        }
        return Bundle(for: MyAppHostAnchor.self)
    }

    @Test("AppMetadata provides valid HTTPS URLs and version formatting")
    func appMetadataProvidesValidURLsAndFormatting() {
        let metadata = AppMetadata.current(bundle: appBundle)

        #expect(metadata.appName.isEmpty == false)
        #expect(metadata.marketingVersion == "1.0.0")
        #expect(metadata.buildNumber.isEmpty == false)
        #expect(metadata.formattedVersion.contains("1.0.0"))

        // Guidelines 1.5 & 5.1.1(i): URLs must use HTTPS and point to github.com
        #expect(metadata.privacyPolicyURL.scheme == "https")
        #expect(metadata.privacyPolicyURL.host == "github.com")
        #expect(metadata.privacyPolicyURL.path.contains("privacy.md"))

        #expect(metadata.supportURL.scheme == "https")
        #expect(metadata.supportURL.host == "github.com")
        #expect(metadata.supportURL.path.contains("support.md"))
    }

    @Test("Bundle declares non-exempt encryption as false (ITSAppUsesNonExemptEncryption)")
    func exportComplianceDeclared() {
        let info = appBundle.infoDictionary
        let nonExempt = info?["ITSAppUsesNonExemptEncryption"] as? Bool

        #expect(nonExempt == false, "ITSAppUsesNonExemptEncryption must be set to NO in build settings")
    }

    @Test("Bundle development region is set to Spanish (es)")
    func developmentRegionIsSpanish() {
        let info = appBundle.infoDictionary
        let region = info?["CFBundleDevelopmentRegion"] as? String

        #expect(region == "es", "CFBundleDevelopmentRegion must be 'es' to align with UI language")
    }

    @Test("Bundle version matches 1.0.0")
    func marketingVersionIsOneZeroZero() {
        let info = appBundle.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String

        #expect(version == "1.0.0", "CFBundleShortVersionString must be 1.0.0 for M6.5 release")
    }

    @Test("PrivacyInfo.xcprivacy exists in bundle and declares zero tracking")
    func privacyManifestExistsAndDeclaresZeroTracking() throws {
        guard let manifestURL = appBundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
            ?? Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
            Issue.record("PrivacyInfo.xcprivacy file not found in bundle resources")
            return
        }

        let data = try Data(contentsOf: manifestURL)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            Issue.record("PrivacyInfo.xcprivacy is not a valid plist dictionary")
            return
        }

        let tracking = plist["NSPrivacyTracking"] as? Bool
        let trackingDomains = plist["NSPrivacyTrackingDomains"] as? [String]
        let collectedData = plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]]

        #expect(tracking == false, "NSPrivacyTracking must be false")
        #expect(trackingDomains?.isEmpty == true, "NSPrivacyTrackingDomains must be empty")
        #expect(collectedData?.isEmpty == true, "NSPrivacyCollectedDataTypes must be empty in v1.0 Local-First")
    }
}

/// Anchor class used by tests to locate the main target bundle if needed.
private final class MyAppHostAnchor {}
