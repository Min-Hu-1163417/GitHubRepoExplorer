//
//  LinkHeaderParserTests.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Testing
import Foundation
@testable import GitHubRepoExplorer

@Suite("Link header parsing")
struct LinkHeaderParserTests {

    @Test("extracts the rel=\"next\" URL from a real GitHub header")
    func parsesNextURL() {
        let header = #"<https://api.github.com/repositories?since=369>; rel="next", <https://api.github.com/repositories{?since}>; rel="first""#

        let next = LinkHeaderParser.nextURL(in: header)

        #expect(next?.absoluteString == "https://api.github.com/repositories?since=369")
    }

    @Test("accepts an unquoted rel parameter")
    func parsesUnquotedRel() {
        let header = "<https://api.github.com/repositories?since=100>; rel=next"

        #expect(LinkHeaderParser.nextURL(in: header)?.absoluteString
                == "https://api.github.com/repositories?since=100")
    }

    @Test("returns nil when there is no next relation (last page)")
    func returnsNilWithoutNext() {
        let header = #"<https://api.github.com/repositories{?since}>; rel="first""#

        #expect(LinkHeaderParser.nextURL(in: header) == nil)
    }

    @Test("returns nil for a missing header")
    func returnsNilForMissingHeader() {
        #expect(LinkHeaderParser.nextURL(in: nil) == nil)
    }
}
