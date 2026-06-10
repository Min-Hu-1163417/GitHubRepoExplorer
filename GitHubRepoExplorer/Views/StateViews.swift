//
//  StateViews.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

/// Full-screen loading state used during the initial fetch.
struct LoadingView: View {
    let text: String

    var body: some View {
        VStack {
            ProgressView()
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Full-screen placeholder for empty or error states: an SF Symbol, a title,
/// and optionally a description and a primary action.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String? = nil
    var action: (title: String, handler: () -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(title)
                .font(.title2.bold())
            if let description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let action {
                Button(action.title, action: action.handler)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Full-screen error state with a retry action (initial load failures only).
struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        EmptyStateView(
            title: "Something went wrong",
            systemImage: "wifi.exclamationmark",
            description: message,
            action: ("Try Again", retry)
        )
    }
}

#Preview("Loading") {
    LoadingView(text: "Loading repositories…")
}

#Preview("Error") {
    ErrorView(message: "You appear to be offline. Check your connection and try again.") {}
}

/// Inline, dismissible banner for non-fatal errors (rate limits, paging
/// failures) that shouldn't replace the content already on screen.
struct TransientBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                Spacer()
                Button("Dismiss", action: dismiss)
                    .font(.footnote)
                    .buttonStyle(.borderless)
            }
        }
    }
}
