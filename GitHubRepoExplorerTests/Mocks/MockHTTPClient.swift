//
//  MockHTTPClient.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation
@testable import GitHubRepoExplorer

/// Test double for the networking layer: returns canned (Data, HTTPURLResponse)
/// pairs without touching the network.
struct MockHTTPClient: HTTPClient {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}

enum TestFixtures {
    static let listURL = URL(string: "https://api.github.com/repositories")!

    /// Two-repo page mimicking `GET /repositories`.
    static let repositoriesJSON = Data("""
    [
      {
        "id": 1,
        "name": "grit",
        "full_name": "mojombo/grit",
        "description": "Grit gives you object oriented read/write access to Git repositories via Ruby.",
        "fork": false,
        "html_url": "https://github.com/mojombo/grit",
        "url": "https://api.github.com/repos/mojombo/grit",
        "owner": {
          "login": "mojombo",
          "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4",
          "type": "User"
        }
      },
      {
        "id": 26,
        "name": "merb-core",
        "full_name": "wycats/merb-core",
        "description": null,
        "fork": true,
        "html_url": "https://github.com/wycats/merb-core",
        "url": "https://api.github.com/repos/wycats/merb-core",
        "owner": {
          "login": "wycats",
          "avatar_url": "https://avatars.githubusercontent.com/u/4?v=4",
          "type": "Organization"
        }
      }
    ]
    """.utf8)

    static let detailJSON = Data("""
    {
      "id": 1,
      "language": "Ruby",
      "stargazers_count": 1962
    }
    """.utf8)

    static func response(
        url: URL = listURL,
        status: Int = 200,
        headers: [String: String] = [:]
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }
}
