# GitHub Repo Explorer

A fully native iOS app that browses GitHub's public repositories, built with SwiftUI and modern Swift concurrency. No third-party libraries.

## Requirements

- Xcode 16+
- iOS 16.0+ (uses `ObservableObject`, `NavigationStack`)

Open `GitHubRepoExplorer.xcodeproj`, select a simulator, and run. Tests: ⌘U.

## Features

- Fetches public repositories from `https://api.github.com/repositories`
- **Grouping** by Owner Type, Fork Status, Language, or Stargazer bands (toolbar menu)
- **Bookmarks** persisted locally as JSON; usable offline from the Bookmarks tab
- **Pagination / infinite scrolling** driven by the HTTP `Link` header
- **Graceful error handling** for offline, decoding, and rate-limit (403) failures
- **Loading states** for initial load, page loads, and per-repo detail fetches
- Unit tests for the networking layer, Link-header parsing, persistence, and grouping logic

## Grouping choice

The default grouping is **Owner Type** (User vs Organization), because that field ships in the list payload and works with zero extra requests. **Fork Status** is also available on the same basis.

**Language** and **Stargazer bands** are implemented as bonus groupings. The `/repositories` list endpoint returns a *minimal* repository representation that does **not** include `language` or `stargazers_count`, so these groupings require one extra request per repository (`GET /repos/{owner}/{repo}`). To keep that affordable:

- Details are fetched **lazily** — only when a detail-dependent grouping is selected (or a detail screen is opened).
- Fetches run with **bounded concurrency** (4 at a time) via a `TaskGroup`, so the app never stampedes the API.
- Results are stored in `DetailCache`, an `actor` that also **coalesces in-flight requests**: concurrent callers asking for the same repository share a single network request.
- Repositories whose details haven't arrived yet appear under a temporary *"Fetching…"* section and migrate into their real section as data lands.

## Pagination strategy

GitHub paginates `/repositories` with a `since` cursor exposed through the RFC 5988 `Link` response header. Per GitHub's documentation, the app **follows the `rel="next"` URL verbatim and never guesses page numbers or cursors** (`LinkHeaderParser`). The view model stores the parsed next URL; when the last visible row appears (`.task` on the row), the next page is requested, de-duplicated by repository ID, and appended. A footer spinner indicates the in-flight page load, and `nextURL == nil` cleanly ends the scroll.

## Error handling

All failures are mapped into a typed `APIError` with user-presentable messages:

| Failure | Detection | Presentation |
|---|---|---|
| Offline / timeout | `URLError` → `.transport` | Full-screen retry view (initial load) or inline banner (later) |
| Decoding | `JSONDecoder` throw → `.decoding` | Same as above |
| Rate limit | HTTP 403/429 **and** `X-RateLimit-Remaining: 0` → `.rateLimited(resetAt:)`, reset time parsed from `X-RateLimit-Reset` | Message includes the local reset time |
| Other HTTP | non-2xx → `.http(statusCode:)` | Generic message with the code |

A deliberate design decision: only the *initial* load failure replaces the screen with a retry state. Failures on subsequent pages or background detail fetches surface as a **dismissible inline banner** so the content the user already has never disappears. When the rate limit is hit during detail prefetching, the task group cancels remaining work immediately instead of burning more quota.

> Tip: the unauthenticated rate limit is 60 requests/hour. You can optionally set a `GITHUB_TOKEN` environment variable in the scheme to authenticate requests (5,000 req/h) while developing. The app works without it.

## Architecture & folder structure

MVVM with a protocol-abstracted networking layer and unidirectional state in an `ObservableObject`, `@MainActor` view model. User-facing copy lives at its point of use (`Text` literals and `String(localized:)`), so it flows through Xcode's String Catalog and stays ready for localization; protocol constants (API headers, URLs) stay in the types that own them rather than a global constants file.

```
GitHubRepoExplorer/
├── App/            Entry point + tab root
├── Models/         Repository, RepoDetail, grouping types
├── Networking/     HTTPClient protocol, GitHubService, LinkHeaderParser, APIError
├── Caching/        DetailCache (actor, request coalescing)
├── Persistence/    BookmarkStore (JSON file in Application Support)
├── ViewModels/     RepoListViewModel (paging, grouping, prefetching)
└── Views/          List, row, detail, bookmarks, loading/error/banner views
GitHubRepoExplorerTests/
├── Mocks/          MockHTTPClient + fixtures
└── …Tests.swift    Networking, Link header, persistence, grouping tests
```

Concurrency notes: all networking is `async/await`; UI state is `@MainActor`-isolated; the detail cache is an `actor`; prefetching uses a `withTaskGroup` with bounded width and cooperative cancellation.

### Modularisation & scalability

The app is modular at the logical level and deliberately monolithic at the physical level. Dependencies flow one way — Views → ViewModel → Service / Cache / Persistence → `HTTPClient` — with plain value `Models` shared underneath; there are no singletons, and every dependency is injected through initialisers with production defaults. `Networking`, `Models`, and `Caching` import no UI frameworks, so lifting them into a local Swift package (e.g. `GitHubAPIKit`) would be a mechanical move, and at multi-feature scale the same seams support a feature-module split (repo browsing, bookmarks) over a shared kernel. Splitting packages now would add build and maintenance overhead without payoff at this size, so it's documented as the growth path rather than done pre-emptively.

## Testing approach

Tests use the Swift Testing framework and focus on the logic most likely to break:

- **`LinkHeaderParserTests`** — real GitHub header shapes, unquoted `rel`, last page, missing header.
- **`GitHubServiceTests`** — decoding a page + next cursor, 403 rate-limit mapping (including the reset date), decoding failures, 5xx mapping. Networking is injected via the `HTTPClient` protocol, so no requests are made.
- **`BookmarkStoreTests`** — toggle semantics and persistence across instances, using a temp-file URL injected into the store.
- **`GroupingTests`** — star-band boundary values (parameterised test) and section ordering.
- **`RepoListViewModelTests`** — the view model driven end-to-end against canned HTTP replies (only the transport is mocked, so real decoding, Link parsing, and error mapping are exercised): initial load, paging with de-duplication, rate-limit banner behaviour, section building, and detail recording. Model stubs and a URL-routing mock (`TestBuilders.swift`) keep these tests free of handwritten JSON.

## Trade-offs / next steps

- Detail cache is in-memory only; persisting it (e.g. `URLCache` or a small disk store) would survive relaunches and save rate limit.
- The `/repositories` feed starts from the oldest public repos (GitHub's `since=0` cursor) — that's inherent to the assigned endpoint.
- With more time: snapshot tests for rows, a `URLProtocol`-based integration test, and offline caching of list pages.
