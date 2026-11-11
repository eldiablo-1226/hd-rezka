import Foundation
import SwiftSoup

/// improvement: posters for lists whose page has none (the site's "continue watching" table). A film page that opens
/// stores its poster here; a missing one is read from the film page once and kept. Keyed by the page path, so it
/// survives a mirror change. Only the newest `limit` entries are kept. Main-actor bound, so concurrent cards can't
/// overwrite each other's writes; only the download and the parse run elsewhere. One request per page at a time,
/// and a page that has no poster (or failed) is not asked again this session.
@MainActor
final class PosterCache {
    static let shared = PosterCache()

    private let defaults: UserDefaults
    private let limit: Int
    private let key = "posterCache"
    private var inFlight: [String: Task<String?, Never>] = [:]
    private var misses: Set<String> = []

    init(defaults: UserDefaults = .standard, limit: Int = 300) {
        self.defaults = defaults
        self.limit = limit
    }

    func poster(for pageURL: String) -> String? {
        entries.first { $0.path == Self.path(pageURL) }?.poster
    }

    func store(_ poster: String, for pageURL: String) {
        guard !poster.isEmpty else { return }
        let path = Self.path(pageURL)
        var list = entries.filter { $0.path != path }
        list.append(Entry(path: path, poster: poster))
        defaults.set(list.suffix(limit).map { [$0.path, $0.poster] }, forKey: key)
    }

    /// The cached poster, else the film page's (fetched from the current mirror and cached); nil when it can't be read.
    func poster(loading pageURL: String, mirror: String, version: String) async -> String? {
        if let poster = poster(for: pageURL) { return poster }
        let path = Self.path(pageURL)
        guard !misses.contains(path) else { return nil }
        if let running = inFlight[path] { return await running.value }
        // Through Alamofire's session, like every site request, so the login cookie goes along (guests get 403).
        let request = try? siteRequest(DetailsViewComponent.pageURL(pageURL, mirror: mirror),
                                       headers: siteHeaders(version: version, contentType: false))
        let task = Task<String?, Never> {
            guard let request, let html = try? await siteString(request) else { return nil }
            return await Task.detached(priority: .utility) { Self.poster(inPage: html) }.value
        }
        inFlight[path] = task
        let poster = await task.value
        inFlight[path] = nil
        if let poster {
            store(poster, for: pageURL)
        } else {
            misses.insert(path)
        }
        return poster
    }

    /// The side cover of a film page (the same image `MovieDetailsParser` takes as `poster`).
    nonisolated static func poster(inPage html: String) -> String? {
        guard let src = try? SwiftSoup.parse(html).getDetailsPoster(), !src.isEmpty else {
            return nil
        }
        return src
    }

    private struct Entry {
        let path: String
        let poster: String
    }

    private var entries: [Entry] {
        (defaults.array(forKey: key) as? [[String]] ?? []).compactMap { $0.count == 2 ? Entry(path: $0[0], poster: $0[1]) : nil }
    }

    nonisolated private static func path(_ pageURL: String) -> String {
        URLComponents(string: pageURL)?.path ?? pageURL
    }
}
