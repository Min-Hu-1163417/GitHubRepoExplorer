//
//  Grouping.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation

/// The fields users can group the repository list by.
/// `language` and `stars` require per-repo detail requests (see `DetailCache`).
enum GroupingOption: String, CaseIterable, Identifiable, Sendable {
    case ownerType = "Owner Type"
    case forkStatus = "Fork Status"
    case language = "Language"
    case stars = "Stars"

    var id: String { rawValue }

    /// Whether this grouping needs data that is only available via extra requests.
    var requiresDetails: Bool {
        self == .language || self == .stars
    }
}

/// Buckets used when grouping by stargazer count.
enum StarBand: Int, CaseIterable, Sendable {
    case none, upTo10, upTo100, upTo1000, over1000

    init(count: Int) {
        switch count {
        case ..<1: self = .none
        case 1...10: self = .upTo10
        case 11...100: self = .upTo100
        case 101...1000: self = .upTo1000
        default: self = .over1000
        }
    }

    var label: String {
        switch self {
        case .none: return "No stars"
        case .upTo10: return "1–10 stars"
        case .upTo100: return "11–100 stars"
        case .upTo1000: return "101–1,000 stars"
        case .over1000: return "1,000+ stars"
        }
    }

    /// Rank used to order star-band sections; unknown titles (e.g. "Fetching…") sort last.
    static func displayRank(of title: String) -> Int {
        allCases.first { $0.label == title }?.rawValue ?? Int.max
    }
}

/// A titled slice of the repository list, ready for rendering as a `Section`.
struct RepoSection: Identifiable {
    let title: String
    let repositories: [Repository]
    var id: String { title }
}
