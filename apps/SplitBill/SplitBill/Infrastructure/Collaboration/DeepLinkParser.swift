import Foundation

/// Parses incoming custom scheme (`splitbill://join?code=...`) and Universal Link
/// (`https://splitbill.app/join?code=...`) URLs into validated `ShareCode` values.
nonisolated enum DeepLinkParser {
    private static let allowedUniversalHosts: Set<String> = [
        "splitbill.app",
        "www.splitbill.app"
    ]

    static func parse(_ url: URL) -> ShareCode? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased() else {
            return nil
        }

        let isValidRoute: Bool
        switch scheme {
        case "splitbill":
            let host = components.host?.lowercased()
            let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            isValidRoute = (host == "join") || (host == nil && normalizedPath == "join")
        case "https":
            let host = components.host?.lowercased() ?? ""
            let pathSegments = components.path
                .split(separator: "/")
                .map { String($0).lowercased() }
            isValidRoute = allowedUniversalHosts.contains(host) && pathSegments.first == "join"
        default:
            isValidRoute = false
        }

        guard isValidRoute else {
            return nil
        }

        if let queryCode = components.queryItems?.first(where: { $0.name.lowercased() == "code" })?.value,
           let parsed = try? ShareCode(rawValue: queryCode) {
            return parsed
        }

        // Also support https://splitbill.app/join/<CODE>
        let pathSegments = components.path.split(separator: "/").map(String.init)
        if pathSegments.count == 2,
           pathSegments[0].lowercased() == "join",
           let parsed = try? ShareCode(rawValue: pathSegments[1]) {
            return parsed
        }

        return nil
    }
}
