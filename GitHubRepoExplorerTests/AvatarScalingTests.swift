//
//  AvatarScalingTests.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 11/06/2026.
//

import Testing
import Foundation
@testable import GitHubRepoExplorer

/// URL building for server-side avatar scaling. Pure function, so this is
/// plain input/output testing — no networking involved.
@Suite("Avatar URL scaling")
struct AvatarScalingTests {

    @Test("appends s=192 after the existing query items")
    func appendsToExistingQuery() {
        let url = URL(string: "https://avatars.githubusercontent.com/u/1?v=4")!

        let scaled = AvatarImage.scaled(url)

        #expect(scaled.absoluteString == "https://avatars.githubusercontent.com/u/1?v=4&s=192")
    }

    @Test("starts a query on URLs that have none")
    func startsQueryWhenAbsent() {
        let url = URL(string: "https://avatars.githubusercontent.com/u/1")!

        let scaled = AvatarImage.scaled(url)

        #expect(scaled.absoluteString == "https://avatars.githubusercontent.com/u/1?s=192")
    }

    @Test("respects a custom pixel size")
    func customPixelSize() {
        let url = URL(string: "https://avatars.githubusercontent.com/u/1?v=4")!

        let scaled = AvatarImage.scaled(url, pixelSize: 88)

        #expect(scaled.absoluteString == "https://avatars.githubusercontent.com/u/1?v=4&s=88")
    }
}
