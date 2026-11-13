import Foundation
import Testing
@testable import SplitBill

@Suite("DeepLinkParser Tests")
struct DeepLinkParserTests {

    @Test("Parses custom splitbill://join?code=... deep link and normalizes lowercase")
    func parsesCustomSchemeDeepLink() throws {
        let url = try #require(URL(string: "splitbill://join?code=ab23cd45"))
        let code = DeepLinkParser.parse(url)
        #expect(code?.value == "AB23CD45")
    }

    @Test("Parses Universal Link https://splitbill.app/join?code=...")
    func parsesUniversalLinkQuery() throws {
        let url = try #require(URL(string: "https://splitbill.app/join?code=ZX98YV76"))
        let code = DeepLinkParser.parse(url)
        #expect(code?.value == "ZX98YV76")
    }

    @Test("Parses Universal Link path format https://www.splitbill.app/join/<code>")
    func parsesUniversalLinkPath() throws {
        let url = try #require(URL(string: "https://www.splitbill.app/join/mn34pq56"))
        let code = DeepLinkParser.parse(url)
        #expect(code?.value == "MN34PQ56")
    }

    @Test("Rejects untrusted domains, unknown schemes, and invalid codes", arguments: [
        "https://evil.example.com/join?code=AB23CD45",
        "http://splitbill.app/join?code=AB23CD45",
        "splitbill://settings?code=AB23CD45",
        "splitbill://join?code=INVALIDO",
        "splitbill://join?code=SHORT",
        "splitbill://join"
    ])
    func rejectsInvalidOrUntrustedURLs(rawURL: String) throws {
        let url = try #require(URL(string: rawURL))
        #expect(DeepLinkParser.parse(url) == nil)
    }
}
