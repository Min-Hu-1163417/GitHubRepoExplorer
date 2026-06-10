//
//  BookmarkStoreTests.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Testing
import Foundation
@testable import GitHubRepoExplorer

@Suite("BookmarkStore")
@MainActor
struct BookmarkStoreTests {

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "bookmarks-\(UUID().uuidString).json")
    }

    @Test("toggle adds and then removes a bookmark")
    func toggleAddsAndRemoves() {
        let store = BookmarkStore(fileURL: temporaryFileURL())
        let repository = Repository.stub()

        store.toggle(repository)
        #expect(store.isBookmarked(repository))

        store.toggle(repository)
        #expect(!store.isBookmarked(repository))
        #expect(store.bookmarks.isEmpty)
    }

    @Test("bookmarks persist across store instances")
    func bookmarksPersistAcrossInstances() {
        let fileURL = temporaryFileURL()
        let repository = Repository.stub(id: 42)

        let first = BookmarkStore(fileURL: fileURL)
        first.toggle(repository)

        let second = BookmarkStore(fileURL: fileURL)
        #expect(second.isBookmarked(repository))
        #expect(second.bookmarks.first?.fullName == "mojombo/grit")

        // Removal must also survive a "relaunch" (a fresh store instance).
        second.toggle(repository)
        let third = BookmarkStore(fileURL: fileURL)
        #expect(!third.isBookmarked(repository))
        #expect(third.bookmarks.isEmpty)
    }
}
