//
//  RepoRowView.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

/// One repository row: avatar, name, description, and metadata tags.
struct RepoRowView: View {
    let repository: Repository
    let detail: RepoDetail?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.fullName)
                    .font(.headline)
                    .lineLimit(1)

                if let description = repository.displayDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    TagView(
                        text: repository.owner.type,
                        systemImage: repository.owner.isOrganization ? "building.2" : "person"
                    )
                    if repository.fork {
                        TagView(text: "Fork", systemImage: "arrow.triangle.branch")
                    }
                    if let detail {
                        if let language = detail.language {
                            TagView(text: language, systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        TagView(text: "\(detail.stargazersCount)", systemImage: "star")
                    }
                }
            }
        }
    }

    private var avatar: some View {
        AvatarImage(url: repository.owner.avatarURL)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Small capsule label used for repository metadata.
struct TagView: View {
    let text: String
    let systemImage: String

    var body: some View {
        // Plain HStack, not a `Label`: inside a `List`, labels adopt the
        // list's icon-column alignment and get a large icon-to-text gap.
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary, in: Capsule())
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// Star toggle backed by the shared `BookmarkStore`.
struct BookmarkButton: View {
    @EnvironmentObject private var bookmarks: BookmarkStore
    let repository: Repository

    var body: some View {
        Button {
            bookmarks.toggle(repository)
        } label: {
            Image(systemName: bookmarks.isBookmarked(repository) ? "star.fill" : "star")
                .foregroundStyle(.yellow)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(
            bookmarks.isBookmarked(repository) ? "Remove bookmark" : "Add bookmark"
        )
    }
}

#Preview {
    List {
        RepoRowView(repository: .preview, detail: .preview)
        RepoRowView(repository: .previewFork, detail: nil)
    }
}
