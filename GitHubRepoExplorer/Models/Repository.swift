//
//  Repository.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation

/// A repository as returned by `GET /repositories`.
///
/// Note: this list endpoint returns a *minimal* representation — it does NOT
/// include `language` or `stargazers_count`. Those live in `RepoDetail` and
/// are fetched lazily per repository (see `DetailCache`).
struct Repository: Identifiable, Codable, Hashable, Sendable {
    struct Owner: Codable, Hashable, Sendable {
        let login: String
        let avatarURL: URL?
        /// Kept as a raw string (not an enum) so unknown future values (e.g.
        /// "Bot") decode fine and form their own group; the only logic that
        /// branches on it goes through `isOrganization`.
        let type: String // "User" or "Organization"

        var isOrganization: Bool { type == "Organization" }

        enum CodingKeys: String, CodingKey {
            case login, type
            case avatarURL = "avatar_url"
        }
    }

    /// GitHub's globally unique repository ID. Used as the identity for list
    /// diffing, paging de-duplication, the `details` cache key, and bookmark
    /// matching.
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let fork: Bool
    let htmlURL: URL?
    /// API URL of the full repository resource (used to fetch `RepoDetail`).
    let apiURL: URL
    let owner: Owner

    /// `description` normalised for display: the API returns both `null` and
    /// empty strings, and either means there is nothing to show.
    var displayDescription: String? {
        guard let description, !description.isEmpty else { return nil }
        return description
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, fork, owner
        case fullName = "full_name"
        case htmlURL = "html_url"
        case apiURL = "url"
    }
}
