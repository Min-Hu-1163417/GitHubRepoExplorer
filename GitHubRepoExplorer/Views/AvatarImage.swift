//
//  AvatarImage.swift
//  GitHubRepoExplorer
//
//  Created by Vincent Hu on 10/06/2026.
//

import SwiftUI

/// Avatar loader with two cache layers: decoded images in an in-memory
/// `NSCache`, raw responses in the shared `URLCache`. The request uses
/// `.returnCacheDataElseLoad`, so a previously fetched avatar is served from
/// disk even after the server's short `max-age` expires — avatar URLs are
/// versioned (`?v=4`), so staleness is not a concern.
struct AvatarImage: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard image == nil, let url else { return }
        if let cached = AvatarCache.shared.image(for: url) {
            image = cached
            return
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = UIImage(data: data) else { return }
        AvatarCache.shared.store(decoded, for: url)
        image = decoded
    }
}

/// Process-wide cache for decoded avatars. `NSCache` is thread-safe and
/// evicts automatically under memory pressure.
final class AvatarCache: @unchecked Sendable {
    static let shared = AvatarCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
