//
//  BookmarksView.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

/// Locally persisted bookmarks; fully usable offline.
struct BookmarksView: View {
    @EnvironmentObject private var bookmarks: BookmarkStore

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.bookmarks.isEmpty {
                    EmptyStateView(
                        title: "No bookmarks yet",
                        systemImage: "star",
                        description: "Tap the star next to a repository to save it here."
                    )
                } else {
                    List {
                        ForEach(bookmarks.bookmarks) { repository in
                            NavigationLink(value: repository) {
                                RepoRowView(repository: repository, detail: nil)
                            }
                            .repoContextMenu(repository: repository)
                            // removing a bookmark isn't data destruction, and
                            // matching by identity avoids index-offset mapping.
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    bookmarks.toggle(repository)
                                } label: {
                                    Label("Remove Bookmark", systemImage: "star.slash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationDestination(for: Repository.self) { repository in
                RepoDetailView(repository: repository)
            }
        }
    }
}

#if DEBUG
#Preview("Populated") {
    BookmarksView()
        .environmentObject(BookmarkStore.preview(populated: true))
}

#Preview("Empty") {
    BookmarksView()
        .environmentObject(BookmarkStore.preview())
}
#endif
