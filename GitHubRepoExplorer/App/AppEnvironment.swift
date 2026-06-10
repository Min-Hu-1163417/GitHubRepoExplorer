//
//  AppEnvironment.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

/// DI seam for views that fetch on their own. Defaults to the production
/// service; `RepoDetailView`'s preview overrides it with a canned client.
/// Lives in the App layer so the Networking layer stays free of SwiftUI imports.
private struct GitHubServiceKey: EnvironmentKey {
    static let defaultValue = GitHubService()
}

extension EnvironmentValues {
    var gitHubService: GitHubService {
        get { self[GitHubServiceKey.self] }
        set { self[GitHubServiceKey.self] = newValue }
    }
}
