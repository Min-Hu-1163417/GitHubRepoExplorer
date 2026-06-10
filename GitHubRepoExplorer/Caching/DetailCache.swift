//
//  DetailCache.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation

/// In-memory cache for per-repository details (language / stargazers).
///
/// Implemented as an `actor` so concurrent callers are safe, and with
/// in-flight task coalescing: if two callers ask for the same repository at
/// the same time, only one network request is made and both await its result.
/// Every detail is an extra request against a 60 req/h unauthenticated rate
/// limit, so duplicates are worth suppressing.
actor DetailCache {
    private let service: GitHubService
    private var cached: [Int: RepoDetail] = [:]
    private var inFlight: [Int: Task<RepoDetail, Error>] = [:]

    init(service: GitHubService) {
        self.service = service
    }

    func detail(for repository: Repository) async throws -> RepoDetail {
        if let detail = cached[repository.id] {
            return detail
        }
        if let task = inFlight[repository.id] {
            return try await task.value
        }

        let task = Task { [service] in
            try await service.detail(at: repository.apiURL)
        }
        inFlight[repository.id] = task
        defer { inFlight[repository.id] = nil }

        let detail = try await task.value
        cached[repository.id] = detail
        return detail
    }
}
