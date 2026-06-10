//
//  BookmarkStore.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation
import Combine
import os

/// Locally persisted bookmarks.
///
/// Stores full `Repository` snapshots (not just IDs) as JSON in Application
/// Support, so the Bookmarks tab works offline and survives relaunches.
/// The file URL is injectable, which lets tests point the store at a
/// temporary directory.
@MainActor
final class BookmarkStore: ObservableObject {
    @Published private(set) var bookmarks: [Repository] = []

    private let fileURL: URL
    private static let logger = Logger(subsystem: "GitHubRepoExplorer", category: "BookmarkStore")

    init(fileURL: URL = BookmarkStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    func isBookmarked(_ repository: Repository) -> Bool {
        bookmarks.contains { $0.id == repository.id }
    }

    func toggle(_ repository: Repository) {
        if let index = bookmarks.firstIndex(where: { $0.id == repository.id }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.append(repository)
        }
        save()
    }

    // MARK: - Persistence

    /// `nonisolated`: default argument values are evaluated outside the main
    /// actor, so this must be callable from a nonisolated context.
    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "bookmarks.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        bookmarks = (try? JSONDecoder().decode([Repository].self, from: data)) ?? []
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(bookmarks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Persistence failure is non-fatal: bookmarks remain usable in
            // memory. `.error` level so the failure is persisted by the
            // unified logging system and visible in Console.app.
            Self.logger.error("Save failed: \(error, privacy: .public)")
        }
    }
}
