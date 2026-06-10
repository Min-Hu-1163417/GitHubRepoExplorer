//
//  RepoDetailView.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

/// Detail screen. Uses the detail preloaded by the list's cache when
/// available; otherwise (e.g. when opened from Bookmarks) it fetches the
/// detail itself and shows an inline loading / error state.
struct RepoDetailView: View {
    let repository: Repository
    var preloadedDetail: RepoDetail? = nil

    @State private var detail: RepoDetail?
    @State private var detailError: String?
    @Environment(\.gitHubService) private var service

    var body: some View {
        List {
            headerSection
            detailsSection
            linkSection
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                BookmarkButton(repository: repository)
            }
        }
        .task {
            if detail == nil { detail = preloadedDetail }
            guard detail == nil else { return }
            do {
                detail = try await service.detail(at: repository.apiURL)
            } catch {
                detailError = (error as? APIError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    // MARK: - Sections

    /// Avatar, name, owner, and full description.
    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                AvatarImage(url: repository.owner.avatarURL)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(repository.name)
                        .font(.title3.bold())
                    Text(repository.owner.login)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = repository.displayDescription {
                Text(description)
            }
        }
    }

    /// List-payload fields plus the lazily fetched detail fields, with
    /// inline loading and error states for the latter.
    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Owner type", value: repository.owner.type)
            LabeledContent("Fork", value: repository.fork ? "Yes" : "No")

            if let detail {
                LabeledContent("Language", value: detail.language ?? "Not detected")
                LabeledContent("Stars", value: "\(detail.stargazersCount)")
            } else if let detailError {
                Label(detailError, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                HStack {
                    Text("Language & stars")
                    Spacer()
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private var linkSection: some View {
        if let url = repository.htmlURL {
            Section {
                Link(destination: url) {
                    Label("View on GitHub", systemImage: "safari")
                }
            }
        }
    }
}

// MARK: - Preview

/// Canned transport so the preview exercises the `\.gitHubService` seam
/// without touching the network (or the rate limit).
private struct PreviewHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body = Data(#"{"id": 1, "language": "Ruby", "stargazers_count": 1962}"#.utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (body, response)
    }
}

#Preview {
    NavigationStack {
        RepoDetailView(repository: .preview)
    }
    .environment(\.gitHubService, GitHubService(client: PreviewHTTPClient(), token: nil))
    .environmentObject(BookmarkStore.preview())
}
