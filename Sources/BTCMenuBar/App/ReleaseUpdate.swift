import Foundation

struct ReleaseUpdate {
    let version: String
    let pageURL: URL

    private struct Release: Decodable {
        let tag: String

        private enum CodingKeys: String, CodingKey {
            case tag = "tag_name"
        }
    }

    static func check(currentVersion: String, session: URLSession) async throws -> Self? {
        let endpoint = URL(string: "https://api.github.com/repos/chenchenwuai/btc-watcher/releases/latest")!
        let (data, response) = try await session.data(from: endpoint)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(Release.self, from: data)
        guard release.tag.range(of: #"\Av[0-9]+\.[0-9]+\.[0-9]+\z"#, options: .regularExpression) != nil,
              let pageURL = URL(string: "https://github.com/chenchenwuai/btc-watcher/releases/tag/\(release.tag)") else {
            throw URLError(.cannotParseResponse)
        }

        let version = String(release.tag.dropFirst())
        guard version.compare(currentVersion, options: .numeric) == .orderedDescending else { return nil }
        return Self(version: release.tag, pageURL: pageURL)
    }
}
