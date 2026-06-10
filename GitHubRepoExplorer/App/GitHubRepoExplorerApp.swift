//
//  GitHubRepoExplorerApp.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

@main
struct GitHubRepoExplorerApp: App {
    @StateObject private var bookmarkStore = BookmarkStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bookmarkStore)
        }
    }
}

/// Top-level tab container: the live repository feed and the locally persisted bookmarks.
struct RootView: View {
    var body: some View {
        TabView {
            RepoListView()
                .tabItem { Label("Repositories", systemImage: "shippingbox") }

            BookmarksView()
                .tabItem { Label("Bookmarks", systemImage: "star") }
        }
    }
}
