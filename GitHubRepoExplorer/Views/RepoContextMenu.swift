//
//  RepoContextMenu.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

/// Long-press preview: blurs the background and shows a preview card plus
/// quick actions (bookmark toggle, open / copy link).
struct RepoContextMenuModifier: ViewModifier {
    @EnvironmentObject private var bookmarks: BookmarkStore
    let repository: Repository
    let detail: RepoDetail?

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                bookmarks.toggle(repository)
            } label: {
                if bookmarks.isBookmarked(repository) {
                    Label("Remove Bookmark", systemImage: "star.slash")
                } else {
                    Label("Add Bookmark", systemImage: "star")
                }
            }

            if let url = repository.htmlURL {
                Link(destination: url) {
                    Label("View on GitHub", systemImage: "safari")
                }
                Button {
                    UIPasteboard.general.url = url
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                }
            }
        } preview: {
            RepoPreviewCard(repository: repository, detail: detail)
        }
    }
}

extension View {
    func repoContextMenu(repository: Repository, detail: RepoDetail? = nil) -> some View {
        modifier(RepoContextMenuModifier(repository: repository, detail: detail))
    }
}

/// Card shown inside the context-menu preview. Renders only data already on
/// hand; a long press never costs a rate-limited request.
struct RepoPreviewCard: View {
    let repository: Repository
    let detail: RepoDetail?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarImage(url: repository.owner.avatarURL)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(repository.name)
                        .font(.headline)
                    Text(repository.owner.login)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = repository.displayDescription {
                Text(description)
                    .font(.subheadline)
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
        .padding()
        .frame(width: 320, alignment: .leading)
    }
}

#Preview("With detail") {
    RepoPreviewCard(repository: .preview, detail: .preview)
}

#Preview("Fork, no detail") {
    RepoPreviewCard(repository: .previewFork, detail: nil)
}

