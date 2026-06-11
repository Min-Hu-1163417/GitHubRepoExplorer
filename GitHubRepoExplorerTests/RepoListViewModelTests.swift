//
//  RepoListViewModelTests.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Testing
import Foundation
@testable import GitHubRepoExplorer

/// Tests the view model end-to-end against canned HTTP replies: only the
/// transport is mocked, so paging, decoding, and error mapping are all real.
@Suite("RepoListViewModel")
@MainActor
struct RepoListViewModelTests {

    private static let page2URL = URL(string: "https://api.github.com/repositories?since=26")!

    private let user = Repository.stub(id: 1)
    private let org = Repository.stub(
        id: 26, name: "merb-core", fork: true,
        ownerLogin: "wycats", ownerType: "Organization"
    )

    @Test("loadFirstPage populates the list and moves to .loaded")
    func firstPageSuccess() async {
        let viewModel = RepoListViewModel(service: .stub(routes: [
            GitHubService.firstPageURL: .page([user, org])
        ]))

        await viewModel.loadFirstPage()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.repositories.count == 2)
        #expect(viewModel.transientMessage == nil)
    }

    @Test("initial load failure surfaces as .failed, not a transient banner")
    func firstPageFailure() async {
        let viewModel = RepoListViewModel(service: .stub(routes: [
            GitHubService.firstPageURL: .serverError()
        ]))

        await viewModel.loadFirstPage()

        if case .failed = viewModel.phase {
            // expected
        } else {
            Issue.record("Expected .failed, got \(viewModel.phase)")
        }
        #expect(viewModel.repositories.isEmpty)
    }

    @Test("infinite scroll follows the Link header and dedups by id")
    func paging() async {
        let viewModel = RepoListViewModel(service: .stub(routes: [
            GitHubService.firstPageURL: .page([user, org], next: Self.page2URL),
            // Page 2 repeats id 26 to verify deduplication.
            Self.page2URL: .page([org, .stub(id: 27, name: "thor", ownerLogin: "wycats")])
        ]))
        await viewModel.loadFirstPage()

        await viewModel.loadMoreIfNeeded(after: viewModel.repositories.last!)

        #expect(viewModel.repositories.map(\.id) == [1, 26, 27])
    }

    @Test("loadMoreIfNeeded ignores rows that are not the last one")
    func pagingOnlyFromLastRow() async {
        let viewModel = RepoListViewModel(service: .stub(routes: [
            GitHubService.firstPageURL: .page([user, org], next: Self.page2URL),
            Self.page2URL: .page([.stub(id: 27)])
        ]))
        await viewModel.loadFirstPage()

        await viewModel.loadMoreIfNeeded(after: viewModel.repositories.first!)

        #expect(viewModel.repositories.count == 2)
    }

    @Test("rate-limited refresh keeps the list and shows a transient message")
    func rateLimitKeepsExistingList() async {
        // First request succeeds; every later one is a 403 rate limit.
        let counter = Counter()
        let firstPage = CannedReply.page([user, org])
        let client = MockHTTPClient { request in
            let reply = counter.next() == 0 ? firstPage : .rateLimited()
            return reply.materialize(url: request.url!)
        }
        let viewModel = RepoListViewModel(service: GitHubService(client: client, token: nil))

        await viewModel.loadFirstPage()
        await viewModel.refresh()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.repositories.count == 2)
        #expect(viewModel.transientMessage != nil)
    }

    @Test("grouping by owner type builds one section per type")
    func ownerTypeSections() async {
        let viewModel = RepoListViewModel(service: .stub(routes: [
            GitHubService.firstPageURL: .page([user, org])
        ]))
        await viewModel.loadFirstPage()

        let sections = viewModel.sections

        #expect(sections.map(\.title) == ["Organization", "User"])
        #expect(sections.first?.repositories.map(\.id) == [26])
    }

    @Test("language grouping keeps repos without details in the pending section")
    func languageGroupingPendingSection() async {
        // Only `user` has a detail route; `org`'s fetch will fail and stay pending.
        let viewModel = RepoListViewModel(service: .stub(routes: [
            GitHubService.firstPageURL: .page([user, org]),
            user.apiURL: .detail(.stub(id: 1, language: "Ruby", stars: 10))
        ]))
        await viewModel.loadFirstPage()
        _ = await viewModel.detail(for: user)

        viewModel.grouping = .language

        let sections = viewModel.sections
        #expect(sections.map(\.title) == ["Ruby", RepoListViewModel.pendingSectionTitle])
        #expect(sections.last?.repositories.map(\.id) == [26])
    }

    @Test("detail(for:) fetches via the cache and records the result")
    func detailFetch() async {
        let viewModel = RepoListViewModel(service: .stub(routes: [
            GitHubService.firstPageURL: .page([user]),
            user.apiURL: .detail(.stub(id: 1, language: "Ruby", stars: 1962))
        ]))
        await viewModel.loadFirstPage()

        let detail = await viewModel.detail(for: user)

        #expect(detail?.language == "Ruby")
        #expect(viewModel.details[1]?.stargazersCount == 1962)
        #expect(viewModel.transientMessage == nil)
    }
}
