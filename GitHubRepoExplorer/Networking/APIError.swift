//
//  APIError.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import Foundation

/// All failures surfaced by the networking layer, mapped to user-presentable messages.
enum APIError: Error, LocalizedError {
    /// The response was not an HTTP response at all.
    case invalidResponse
    /// A transport-level failure (offline, timeout, DNS, …).
    case transport(URLError)
    /// The payload could not be decoded into the expected model.
    case decoding(Error)
    /// GitHub's unauthenticated rate limit (60 req/h) was exceeded (HTTP 403/429
    /// with `X-RateLimit-Remaining: 0`).
    case rateLimited(resetAt: Date?)
    /// Any other non-2xx status code.
    case http(statusCode: Int)

    /// `String(localized:)` routes these through the String Catalog, like the
    /// SwiftUI `Text` literals in the views, keeping all copy localizable.
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "The server returned an unexpected response.")
        case .transport(let urlError):
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return String(localized: "You appear to be offline. Check your connection and try again.")
            case .timedOut:
                return String(localized: "The request timed out. Please try again.")
            default:
                return String(localized: "A network error occurred. Please try again.")
            }
        case .decoding:
            return String(localized: "Couldn't read the data returned by GitHub.")
        case .rateLimited(let resetAt):
            if let resetAt {
                let time = resetAt.formatted(date: .omitted, time: .shortened)
                return String(localized: "GitHub's rate limit was reached. It resets at \(time).")
            }
            return String(localized: "GitHub's rate limit was reached. Please try again later.")
        case .http(let statusCode):
            return String(localized: "GitHub returned an error (HTTP \(statusCode)).")
        }
    }
}
