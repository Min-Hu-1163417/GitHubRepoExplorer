//
//  PreviewData.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation

#if DEBUG
/// Shared sample data for Xcode previews. Compiled out of release builds.
extension Repository {
    static let preview = Repository(
        id: 1,
        name: "grit",
        fullName: "mojombo/grit",
        description: "Grit gives you object oriented read/write access to Git repositories via Ruby.",
        fork: false,
        htmlURL: URL(string: "https://github.com/mojombo/grit"),
        apiURL: URL(string: "https://api.github.com/repos/mojombo/grit")!,
        owner: .init(
            login: "mojombo",
            avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1?v=4"),
            type: "User"
        )
    )

    static let previewFork = Repository(
        id: 26,
        name: "merb-core",
        fullName: "wycats/merb-core",
        description: nil,
        fork: true,
        htmlURL: URL(string: "https://github.com/wycats/merb-core"),
        apiURL: URL(string: "https://api.github.com/repos/wycats/merb-core")!,
        owner: .init(
            login: "wycats",
            avatarURL: URL(string: "https://avatars.githubusercontent.com/u/4?v=4"),
            type: "Organization"
        )
    )
}

extension RepoDetail {
    static let preview = RepoDetail(id: 1, language: "Ruby", stargazersCount: 1962)
}

extension BookmarkStore {
    /// Store backed by a throwaway file so previews never touch real bookmarks.
    static func preview(populated: Bool = false) -> BookmarkStore {
        let store = BookmarkStore(
            fileURL: FileManager.default.temporaryDirectory
                .appending(path: "preview-bookmarks-\(UUID().uuidString).json")
        )
        if populated {
            store.toggle(.preview)
            store.toggle(.previewFork)
        }
        return store
    }
}
#endif
