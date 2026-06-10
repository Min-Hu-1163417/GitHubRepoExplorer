import Testing
import Foundation
@testable import GitHubRepoExplorer

/// Verifies the cache's two guarantees: a detail is fetched at most once per
/// repository (in-flight coalescing + caching), and failures are not cached.
@Suite("DetailCache")
struct DetailCacheTests {

    private let repository = Repository.stub(id: 1)

    /// Service whose transport counts every request before replying.
    private func makeService(counting counter: Counter,
                             reply: @escaping @Sendable (Int) -> CannedReply) -> GitHubService {
        let client = MockHTTPClient { request in
            let n = counter.next()
            return reply(n).materialize(url: request.url!)
        }
        return GitHubService(client: client, token: nil)
    }

    @Test("concurrent callers for the same repository share one request")
    func coalescesConcurrentRequests() async throws {
        let counter = Counter()
        let service = makeService(counting: counter) { _ in .detail(.stub(id: 1)) }
        let cache = DetailCache(service: service)

        // Ten concurrent callers racing for the same repository.
        let details = try await withThrowingTaskGroup(of: RepoDetail.self) { group in
            for _ in 0..<10 {
                group.addTask { [repository] in
                    try await cache.detail(for: repository)
                }
            }
            return try await group.reduce(into: [RepoDetail]()) { $0.append($1) }
        }

        #expect(details.count == 10)
        #expect(Set(details).count == 1)
        #expect(counter.current == 1)
    }

    @Test("a cached detail is served without a second request")
    func cacheHitSkipsNetwork() async throws {
        let counter = Counter()
        let service = makeService(counting: counter) { _ in .detail(.stub(id: 1, stars: 7)) }
        let cache = DetailCache(service: service)

        let first = try await cache.detail(for: repository)
        let second = try await cache.detail(for: repository)

        #expect(first == second)
        #expect(counter.current == 1)
    }

    @Test("a failed fetch is not cached; the next call retries")
    func failureIsNotCached() async throws {
        let counter = Counter()
        // First request fails with a 500; the retry succeeds.
        let service = makeService(counting: counter) { n in
            n == 0 ? .serverError() : .detail(.stub(id: 1))
        }
        let cache = DetailCache(service: service)

        await #expect(throws: APIError.self) {
            try await cache.detail(for: repository)
        }

        let detail = try await cache.detail(for: repository)
        #expect(detail.id == 1)
        #expect(counter.current == 2)
    }
}
