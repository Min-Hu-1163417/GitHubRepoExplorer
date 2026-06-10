//
//  TestBuilders.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation
@testable import GitHubRepoExplorer

// MARK: - Model stubs

extension Repository {
    /// Valid repository with sensible defaults; override only what the test cares about.
    /// `apiURL` embeds the id so detail requests can be routed per repository.
    static func stub(
        id: Int = 1,
        name: String = "grit",
        fullName: String? = nil,
        description: String? = "A test repository",
        fork: Bool = false,
        ownerLogin: String = "mojombo",
        ownerType: String = "User"
    ) -> Repository {
        Repository(
            id: id,
            name: name,
            fullName: fullName ?? "\(ownerLogin)/\(name)",
            description: description,
            fork: fork,
            htmlURL: URL(string: "https://github.com/\(ownerLogin)/\(name)"),
            apiURL: URL(string: "https://api.github.com/repos/stub/\(id)")!,
            owner: .init(login: ownerLogin, avatarURL: nil, type: ownerType)
        )
    }
}

extension RepoDetail {
    static func stub(id: Int = 1, language: String? = "Ruby", stars: Int = 42) -> RepoDetail {
        RepoDetail(id: id, language: language, stargazersCount: stars)
    }
}

// MARK: - Canned replies

/// A canned HTTP reply (status + headers + body), `Sendable` so it can be
/// captured in mock handlers. Bodies are produced by encoding model stubs
/// through their `CodingKeys`, so tests rarely hand-write JSON. Field mapping
/// against real GitHub payloads stays covered by `GitHubServiceTests`, which
/// keeps handwritten fixtures for that reason.
struct CannedReply: Sendable {
    var status: Int = 200
    var headers: [String: String] = [:]
    var body: Data = Data()

    /// One repositories page; pass `next` to emit a `Link: rel="next"` header.
    static func page(_ repositories: [Repository], next: URL? = nil) -> CannedReply {
        var headers: [String: String] = [:]
        if let next {
            headers["Link"] = "<\(next.absoluteString)>; rel=\"next\""
        }
        return CannedReply(headers: headers, body: try! JSONEncoder().encode(repositories))
    }

    static func detail(_ detail: RepoDetail) -> CannedReply {
        CannedReply(body: try! JSONEncoder().encode(detail))
    }

    static func rateLimited(resetEpoch: Int = 1_750_000_000) -> CannedReply {
        CannedReply(status: 403, headers: [
            "X-RateLimit-Remaining": "0",
            "X-RateLimit-Reset": String(resetEpoch)
        ])
    }

    static func serverError(status: Int = 500) -> CannedReply {
        CannedReply(status: status)
    }

    func materialize(url: URL) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (body, response)
    }
}

// MARK: - Routing mock

extension MockHTTPClient {
    /// Returns canned replies keyed by exact request URL; unmatched URLs get a 404.
    static func routing(_ routes: [URL: CannedReply]) -> MockHTTPClient {
        MockHTTPClient { request in
            let url = request.url!
            let reply = routes[url] ?? CannedReply(status: 404)
            return reply.materialize(url: url)
        }
    }
}

extension GitHubService {
    /// Service backed by a routing mock; token is nil so tests ignore `GITHUB_TOKEN`.
    static func stub(routes: [URL: CannedReply]) -> GitHubService {
        GitHubService(client: MockHTTPClient.routing(routes), token: nil)
    }
}

// MARK: - Utilities

/// Minimal thread-safe counter for sequencing responses inside `@Sendable` handlers.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        let current = value
        value += 1
        return current
    }
}
