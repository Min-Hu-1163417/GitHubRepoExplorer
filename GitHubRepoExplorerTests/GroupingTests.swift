//
//  GroupingTests.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Testing
@testable import GitHubRepoExplorer

@Suite("Star band grouping")
struct GroupingTests {

    @Test(
        "star counts fall into the expected bands (boundary values)",
        arguments: [
            (0, StarBand.none),
            (1, .upTo10), (10, .upTo10),
            (11, .upTo100), (100, .upTo100),
            (101, .upTo1000), (1000, .upTo1000),
            (1001, .over1000), (50_000, .over1000)
        ]
    )
    func bandBoundaries(count: Int, expected: StarBand) {
        #expect(StarBand(count: count) == expected)
    }

    @Test("section ordering puts unknown titles last")
    func displayRankOrdersUnknownLast() {
        #expect(StarBand.displayRank(of: StarBand.none.label) == 0)
        #expect(StarBand.displayRank(of: StarBand.over1000.label) == 4)
        #expect(StarBand.displayRank(of: "Fetching…") == Int.max)
    }

    @Test("groupings that need extra requests are flagged")
    func requiresDetails() {
        #expect(GroupingOption.language.requiresDetails)
        #expect(GroupingOption.stars.requiresDetails)
        #expect(!GroupingOption.ownerType.requiresDetails)
        #expect(!GroupingOption.forkStatus.requiresDetails)
    }
}
