//
//  RepoListView.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

/// Main screen: grouped, infinitely scrolling list of public repositories.
struct RepoListView: View {
    @StateObject private var viewModel = RepoListViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Repositories")
                .navigationDestination(for: Repository.self) { repository in
                    RepoDetailView(
                        repository: repository,
                        preloadedDetail: viewModel.details[repository.id]
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        groupingMenu
                    }
                }
        }
        .task {
            if viewModel.phase == .idle {
                await viewModel.loadFirstPage()
            }
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LoadingView(text: "Loading repositories…")

        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.loadFirstPage() }
            }

        case .loaded:
            repoList
        }
    }

    private var repoList: some View {
        ScrollViewReader { proxy in
            List {
                if let message = viewModel.transientMessage {
                    TransientBanner(message: message) {
                        viewModel.dismissTransientMessage()
                    }
                }

                sectionList
                loadingMoreRow
            }
            .animation(.default, value: viewModel.grouping)
            .refreshable {
                await viewModel.refresh()
            }
            // A new grouping invalidates the old scroll position, so jump
            // back to the top.
            .onChange(of: viewModel.grouping) { _ in
                if let first = viewModel.sections.first?.id {
                    proxy.scrollTo(first, anchor: .top)
                }
            }
        }
    }

    private var sectionList: some View {
        ForEach(viewModel.sections) { section in
            Section(section.title) {
                ForEach(section.repositories) { repository in
                    NavigationLink(value: repository) {
                        HStack(spacing: 8) {
                            RepoRowView(
                                repository: repository,
                                detail: viewModel.details[repository.id]
                            )
                            Spacer(minLength: 0)
                            BookmarkButton(repository: repository)
                        }
                    }
                    .repoContextMenu(
                        repository: repository,
                        detail: viewModel.details[repository.id]
                    )
                    .task {
                        await viewModel.loadMoreIfNeeded(after: repository)
                    }
                }
            }
            // Explicit anchor so the ScrollViewReader above can scroll back
            // to the first section when the grouping changes.
            .id(section.id)
        }
    }

    @ViewBuilder
    private var loadingMoreRow: some View {
        if viewModel.isLoadingMore {
            HStack {
                Spacer()
                ProgressView("Loading more…")
                    // Known SwiftUI bug: a reused ProgressView in a List stops
                    // showing its spinner after the row is re-inserted. A fresh
                    // id forces the indicator to be recreated each time.
                    .id(UUID())
                Spacer()
            }
            .listRowSeparator(.hidden)
        }
    }

    private var groupingMenu: some View {
        Menu {
            Picker("Group by", selection: $viewModel.grouping) {
                ForEach(GroupingOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Label("Group by", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

#Preview {
    RepoListView()
        .environmentObject(BookmarkStore())
}
