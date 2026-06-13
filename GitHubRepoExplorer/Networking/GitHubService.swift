//
//  GitHubService.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation
import os

/// One page of results plus the cursor (full URL) for the next page, if any.
struct Page<Item: Sendable>: Sendable {
    let items: [Item]
    let nextURL: URL?
}

/// Stateless GitHub REST client. All requests go through the injected
/// `HTTPClient`, which keeps this type fully unit-testable without networking.
struct GitHubService: Sendable {
    private static let logger = Logger(subsystem: "GitHubRepoExplorer", category: "GitHubService")

    /// Safe to unwrap: compile-time literal, and a typo should crash at
    /// startup rather than surface later. Runtime URLs (Link header) stay optional.
    static let firstPageURL = URL(string: "https://api.github.com/repositories")!

    private let client: any HTTPClient
    private let token: String?

    /// - Parameters:
    ///   - client: transport; defaults to a real URLSession-backed client.
    ///   - token: optional personal access token. Picked up from the
    ///     `GITHUB_TOKEN` scheme environment variable to raise the rate limit
    ///     from 60 to 5,000 req/h during development. Never required.
    init(client: any HTTPClient = URLSessionHTTPClient(),
         token: String? = ProcessInfo.processInfo.environment["GITHUB_TOKEN"]) {
        self.client = client
        self.token = token
    }

    /// Fetches one page of public repositories and the `rel="next"` cursor.
    func repositories(at url: URL = GitHubService.firstPageURL) async throws -> Page<Repository> {
        let (data, response) = try await send(url)
        let items: [Repository] = try Self.decode(data)
        let next = LinkHeaderParser.nextURL(in: response.value(forHTTPHeaderField: "Link"))
        return Page(items: items, nextURL: next)
    }

    /// Fetches the full repository resource (language, stargazers, …).
    func detail(at url: URL) async throws -> RepoDetail {
        let (data, _) = try await send(url)
        return try Self.decode(data)
    }

    // MARK: - Internals

    private func send(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await client.data(for: request)
        try Self.validate(response)
        return (data, response)
    }

    /// Maps non-2xx responses to typed errors, with special handling for
    /// GitHub's rate limit (403/429 + `X-RateLimit-Remaining: 0`).
    static func validate(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 403, 429:
            // Rate limiting is signalled by an exhausted quota, not by the
            // status code alone: GitHub also returns 403 for per-repository
            // restrictions (e.g. DMCA-blocked repos), and X-RateLimit-Reset
            // is present on every response, so neither is evidence by itself.
            if response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                let resetEpoch = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
                    .flatMap(TimeInterval.init)
                throw APIError.rateLimited(resetAt: resetEpoch.map(Date.init(timeIntervalSince1970:)))
            }
            throw APIError.http(statusCode: response.statusCode)
        default:
            throw APIError.http(statusCode: response.statusCode)
        }
    }

    private static func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // The one failure the transport log can't see: the HTTP line says
            // 200, but the payload didn't match our model — usually a sign
            // the API changed shape. The DecodingError detail lives only here.
            Self.logger.error("Decoding \(T.self) failed: \(error, privacy: .public)")
            throw APIError.decoding(error)
        }
    }
}
