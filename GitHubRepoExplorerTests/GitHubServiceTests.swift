//
//  GitHubServiceTests.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Testing
import Foundation
@testable import GitHubRepoExplorer

@Suite("GitHubService")
struct GitHubServiceTests {

    @Test("decodes a repositories page and follows the Link header")
    func decodesRepositoriesPage() async throws {
        let headers = ["Link": #"<https://api.github.com/repositories?since=26>; rel="next""#]
        let client = MockHTTPClient { _ in
            (TestFixtures.repositoriesJSON, TestFixtures.response(headers: headers))
        }
        let service = GitHubService(client: client, token: nil)

        let page = try await service.repositories()

        #expect(page.items.count == 2)
        #expect(page.items.first?.fullName == "mojombo/grit")
        #expect(page.items.first?.owner.type == "User")
        #expect(page.items.last?.fork == true)
        #expect(page.nextURL?.absoluteString == "https://api.github.com/repositories?since=26")
    }

    @Test("maps 403 with exhausted rate limit to .rateLimited with a reset date")
    func mapsRateLimit() async {
        let headers = [
            "X-RateLimit-Remaining": "0",
            "X-RateLimit-Reset": "1750000000"
        ]
        let client = MockHTTPClient { _ in
            (Data(), TestFixtures.response(status: 403, headers: headers))
        }
        let service = GitHubService(client: client, token: nil)

        do {
            _ = try await service.repositories()
            Issue.record("Expected APIError.rateLimited to be thrown")
        } catch APIError.rateLimited(let resetAt) {
            #expect(resetAt == Date(timeIntervalSince1970: 1_750_000_000))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("maps malformed JSON to .decoding")
    func mapsDecodingFailure() async {
        let client = MockHTTPClient { _ in
            (Data("not json".utf8), TestFixtures.response())
        }
        let service = GitHubService(client: client, token: nil)

        do {
            _ = try await service.repositories()
            Issue.record("Expected APIError.decoding to be thrown")
        } catch APIError.decoding {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("maps other non-2xx statuses to .http")
    func mapsServerError() async {
        let client = MockHTTPClient { _ in
            (Data(), TestFixtures.response(status: 500))
        }
        let service = GitHubService(client: client, token: nil)

        do {
            _ = try await service.repositories()
            Issue.record("Expected APIError.http to be thrown")
        } catch APIError.http(let statusCode) {
            #expect(statusCode == 500)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("decodes a repository detail")
    func decodesDetail() async throws {
        let client = MockHTTPClient { _ in
            (TestFixtures.detailJSON, TestFixtures.response())
        }
        let service = GitHubService(client: client, token: nil)

        let detail = try await service.detail(
            at: URL(string: "https://api.github.com/repos/mojombo/grit")!
        )

        #expect(detail.language == "Ruby")
        #expect(detail.stargazersCount == 1962)
    }
}
