//
//  RepoListViewModel.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation
import Combine

/// Drives the repository list: paging, grouping, lazy detail fetching, and
/// turning errors into presentable state.
@MainActor
final class RepoListViewModel: ObservableObject {
    /// Lifecycle of the *initial* load. Errors on later pages or detail
    /// fetches don't blow away the list — they surface via `transientMessage`.
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    // MARK: - Observable state

    @Published private(set) var repositories: [Repository] = []
    @Published private(set) var details: [Int: RepoDetail] = [:]
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isLoadingMore = false
    /// Non-fatal error banner (e.g. rate-limited while prefetching details).
    @Published private(set) var transientMessage: String?

    /// Switching to a detail-dependent grouping (language / stars) kicks off
    /// prefetching for repositories whose details haven't been fetched yet.
    @Published var grouping: GroupingOption = .ownerType {
        didSet {
            guard grouping.requiresDetails else { return }
            // Unstructured task: capture self weakly so a pending prefetch
            // never extends the view model's lifetime.
            Task { [weak self] in await self?.loadMissingDetails() }
        }
    }

    // MARK: - Dependencies

    private let service: GitHubService
    private let detailCache: DetailCache
    private var nextURL: URL?
    private var isFetchingDetails = false

    /// - Parameter detailCache: injectable for tests; defaults to a cache
    ///   backed by the same service.
    init(service: GitHubService = GitHubService(), detailCache: DetailCache? = nil) {
        self.service = service
        self.detailCache = detailCache ?? DetailCache(service: service)
    }

    // MARK: - Loading

    /// Initial load (and retry). Shows the full-screen loading state only
    /// while there is nothing to display yet.
    func loadFirstPage() async {
        if repositories.isEmpty { phase = .loading }
        await refresh()
    }

    /// Pull-to-refresh: reload from the first page, keeping the current list
    /// on screen if the refresh fails.
    func refresh() async {
        do {
            let page = try await service.repositories()
            repositories = page.items
            nextURL = page.nextURL
            transientMessage = nil
            phase = .loaded
            if grouping.requiresDetails {
                await loadMissingDetails()
            }
        } catch {
            if repositories.isEmpty {
                phase = .failed(Self.message(for: error))
            } else {
                transientMessage = Self.message(for: error)
            }
        }
    }

    /// Infinite scrolling: called when a row appears; fetches the next page
    /// once the last row is reached, following the Link header cursor.
    func loadMoreIfNeeded(after repository: Repository) async {
        guard repository.id == repositories.last?.id,
              let next = nextURL,
              !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await service.repositories(at: next)
            let existing = Set(repositories.map(\.id))
            repositories.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            nextURL = page.nextURL
            if grouping.requiresDetails {
                await loadMissingDetails()
            }
        } catch {
            transientMessage = Self.message(for: error)
        }
    }

    func dismissTransientMessage() {
        transientMessage = nil
    }

    /// Used by the detail screen; reads through the cache and records the result.
    func detail(for repository: Repository) async -> RepoDetail? {
        if let detail = details[repository.id] { return detail }
        do {
            let detail = try await detailCache.detail(for: repository)
            details[repository.id] = detail
            return detail
        } catch {
            transientMessage = Self.message(for: error)
            return nil
        }
    }

    // MARK: - Detail prefetching (language / stars grouping)

    /// Fetches missing details with bounded concurrency (4 at a time) so we
    /// don't stampede the API. Stops early if the rate limit is hit.
    private func loadMissingDetails() async {
        guard grouping.requiresDetails, !isFetchingDetails else { return }
        isFetchingDetails = true
        defer { isFetchingDetails = false }

        let missing = repositories.filter { details[$0.id] == nil }
        guard !missing.isEmpty else { return }

        let cache = detailCache
        let initialBatch = min(4, missing.count)
        var nextIndex = initialBatch
        var rateLimited = false

        await withTaskGroup(of: (Int, Result<RepoDetail, Error>).self) { group in
            for repository in missing.prefix(initialBatch) {
                group.addTask { await Self.fetchDetail(for: repository, using: cache) }
            }

            for await (id, result) in group {
                switch result {
                case .success(let detail):
                    details[id] = detail
                case .failure(let error):
                    if case APIError.rateLimited = error, !rateLimited {
                        rateLimited = true
                        transientMessage = Self.message(for: error)
                        group.cancelAll()
                    }
                }

                if !rateLimited, nextIndex < missing.count {
                    let repository = missing[nextIndex]
                    nextIndex += 1
                    group.addTask { await Self.fetchDetail(for: repository, using: cache) }
                }
            }
        }
    }

    /// `nonisolated`: touches no main-actor state, so group children run it
    /// on the cooperative pool instead of hopping through the main actor.
    private nonisolated static func fetchDetail(
        for repository: Repository,
        using cache: DetailCache
    ) async -> (Int, Result<RepoDetail, Error>) {
        do {
            let detail = try await cache.detail(for: repository)
            return (repository.id, .success(detail))
        } catch {
            return (repository.id, .failure(error))
        }
    }

    // MARK: - Grouping

    static let pendingSectionTitle = "Fetching…"

    /// Derived on demand from `repositories` + `details` + `grouping` rather
    /// than stored, so it can never go stale. Cheap at this scale; if paging
    /// grows into thousands of rows, memoise on the three inputs.
    var sections: [RepoSection] {
        switch grouping {
        case .ownerType:
            return makeSections { $0.owner.type }

        case .forkStatus:
            return makeSections { $0.fork ? "Forks" : "Source repositories" }

        case .language:
            let pending = Self.pendingSectionTitle
            return makeSections(order: { a, b in
                if a == pending { return false }
                if b == pending { return true }
                return a < b
            }) { repository in
                guard let detail = details[repository.id] else { return pending }
                return detail.language ?? "No language detected"
            }

        case .stars:
            // Value-type snapshot so the (implicitly escaping) optional
            // closure captures the dictionary, not self.
            let details = details
            return makeSections(order: { a, b in
                StarBand.displayRank(of: a) < StarBand.displayRank(of: b)
            }, rowOrder: { a, b in
                // Within a band, most-starred first; tie-break by id so the
                // order is deterministic across regroups.
                let starsA = details[a.id]?.stargazersCount ?? 0
                let starsB = details[b.id]?.stargazersCount ?? 0
                return starsA != starsB ? starsA > starsB : a.id < b.id
            }) { repository in
                guard let detail = details[repository.id] else { return Self.pendingSectionTitle }
                return StarBand(count: detail.stargazersCount).label
            }
        }
    }

    /// Groups repositories into titled sections. `order` controls section
    /// ordering (`nil` means alphabetical); `rowOrder` optionally sorts rows
    /// within each section (`nil` keeps feed order).
    private func makeSections(
        order: ((String, String) -> Bool)? = nil,
        rowOrder: ((Repository, Repository) -> Bool)? = nil,
        key: (Repository) -> String
    ) -> [RepoSection] {
        let grouped = Dictionary(grouping: repositories, by: key)
        let titles = grouped.keys.sorted(by: order ?? { $0 < $1 })
        return titles.map { title in
            var rows = grouped[title] ?? []
            if let rowOrder { rows.sort(by: rowOrder) }
            return RepoSection(title: title, repositories: rows)
        }
    }

    // MARK: - Error presentation

    private static func message(for error: Error) -> String {
        (error as? APIError)?.errorDescription ?? error.localizedDescription
    }
}
