//
//  HTTPClient.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation
import os

/// Thin abstraction over URLSession so the networking layer can be unit tested
/// with canned responses (see `MockHTTPClient` in the test target).
protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    /// Transport-level observability at `.debug` (in-memory only, never
    /// persisted): status, path, and quota headers per request. This is what
    /// distinguishes the three different 403s GitHub can return.
    private static let logger = Logger(subsystem: "GitHubRepoExplorer", category: "HTTP")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            Self.logger.debug("""
            \(http.statusCode) \(request.url?.path ?? "", privacy: .public) \
            limit=\(http.value(forHTTPHeaderField: "X-RateLimit-Limit") ?? "?", privacy: .public) \
            remaining=\(http.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "?", privacy: .public)
            """)
            return (data, http)
        } catch let urlError as URLError {
            Self.logger.debug("""
            FAILED \(request.url?.path ?? "", privacy: .public) \
            code=\(urlError.code.rawValue) \(urlError.localizedDescription, privacy: .public)
            """)
            throw APIError.transport(urlError)
        }
    }
}
