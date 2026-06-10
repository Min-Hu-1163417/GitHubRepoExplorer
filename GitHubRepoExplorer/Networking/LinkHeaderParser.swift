//
//  LinkHeaderParser.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation

/// Parses the RFC 5988 `Link` header GitHub uses for pagination, e.g.
///
///     <https://api.github.com/repositories?since=369>; rel="next",
///     <https://api.github.com/repositories{?since}>; rel="first"
///
/// Per GitHub's docs we always follow the `rel="next"` URL verbatim and never
/// guess page numbers or `since` cursors ourselves.
enum LinkHeaderParser {
    static func nextURL(in header: String?) -> URL? {
        guard let header else { return nil }

        for entry in header.split(separator: ",") {
            let segments = entry
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard let target = segments.first,
                  target.hasPrefix("<"), target.hasSuffix(">") else { continue }

            let isNext = segments.dropFirst().contains { segment in
                let normalized = segment.replacingOccurrences(of: " ", with: "")
                return normalized == "rel=\"next\"" || normalized == "rel=next"
            }

            if isNext {
                let urlString = String(target.dropFirst().dropLast())
                return URL(string: urlString)
            }
        }
        return nil
    }
}
