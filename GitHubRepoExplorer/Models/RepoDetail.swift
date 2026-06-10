//
//  RepoDetail.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation

/// The subset of `GET /repos/{owner}/{repo}` we care about.
/// Fetched on demand and cached, because the list endpoint omits these fields.
struct RepoDetail: Codable, Hashable, Sendable {
    /// Same GitHub repository ID as `Repository.id`; pairs a detail back to
    /// the list entry it belongs to.
    let id: Int
    let language: String?
    let stargazersCount: Int

    enum CodingKeys: String, CodingKey {
        case id, language
        case stargazersCount = "stargazers_count"
    }
}
