import Foundation
import SwiftUI
import Alamofire
import SwiftSoup

/// Main-actor bound: views observe these lists, so every change must happen on main (the original
/// published from a background task, which Nuke 12.9's LazyImage turns into a crash).
@MainActor
class Network: ObservableObject {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = "0.0.0"
    @Published var movies: [MovieSimple] = []
    @Published var bookmarks: [MovieSimple] = []
    @Published var search: [MovieSimple] = []
    @Published var quickSearch: [SearchResult] = []
    /// improvement: the last listing request found nothing to show (no body, a parse error, or still no movies).
    @Published var moviesLoadFailed = false
    /// improvement: why the last listing request failed, for Home's error message.
    @Published var moviesLoadFailure: PageLoadFailure = .other
    /// improvement: the arguments of the last `fetchMovies`, re-sent by `retryMovies()`.
    private var lastMoviesRequest: (page: Int, filter: String)?
    /// improvement: pull to refresh. Answers to requests sent before the last `beginRefresh()` are dropped, and the next
    /// page replaces the list only when it brings movies, so a failed refresh keeps what is on screen.
    private(set) var moviesGeneration = 0
    private var replaceOnNextPage = false
    /// A refresh failed while the list stayed on screen; Home shows a short notice and clears it.
    @Published var moviesRefreshFailed = false
    private var pageWaiters: [CheckedContinuation<Void, Never>] = []

    nonisolated init() {}  // AccountService creates one off the main actor

    /// Fire-and-forget like the original: returns at once, the page is appended to `movies` when it
    /// arrives. 1.6.0 dropped network and parse errors; they now set `moviesLoadFailed`.
    func fetchMovies(page: Int, filter: String) async throws {
        lastMoviesRequest = (page, filter)
        let generation = moviesGeneration
        AF.request(moviesURL(page: page, filter: filter), headers: siteHeaders(version: remoteVersion, contentType: false))
            .responseString { response in
                self.receivePage(response.value,
                                 failure: PageLoadFailure(error: response.error, statusCode: response.response?.statusCode),
                                 generation: generation, page: page)
            }
    }

    /// Starts over from page 1 without clearing the list: the caller fetches page 1, which then replaces it.
    func beginRefresh() {
        moviesGeneration += 1
        replaceOnNextPage = true
        moviesLoadFailed = false
    }

    private func resumePageWaiters() {
        let waiters = pageWaiters
        pageWaiters = []
        waiters.forEach { $0.resume() }
    }

    /// Returns when the next listing page has been handled (pull to refresh keeps its spinner until then).
    func nextPageArrival() async {
        await withCheckedContinuation { pageWaiters.append($0) }
    }

    /// The arrived listing page, parsed in a new task (on the main actor, like everything here).
    func receivePage(_ html: String?, failure: PageLoadFailure = .other, generation: Int? = nil, page: Int? = nil) {
        Task {
            guard generation == nil || generation == self.moviesGeneration else {
                // Dropped, but a refresh waiting on "the next page" must not spin forever if this was the last answer.
                self.resumePageWaiters()
                return
            }
            self.moviesLoadFailure = failure
            self.finishMoviesRequest(html: html, page: page)
        }
    }

    /// Parses an arrived listing page. improvement: no body, a parse error or a page that still leaves `movies`
    /// empty sets `moviesLoadFailed`, so Home offers Retry.
    func finishMoviesRequest(html: String?, page: Int? = nil) {
        defer { resumePageWaiters() }
        if replaceOnNextPage && (page ?? 1) == 1 {
            replaceOnNextPage = false
            let previous = movies
            movies = []
            if html.flatMap({ try? parse(html: $0) }) == nil || movies.isEmpty {
                movies = previous
                moviesRefreshFailed = !previous.isEmpty
                moviesLoadFailed = previous.isEmpty
            }
            return
        }
        let parsed = html.flatMap { try? parse(html: $0) } != nil
        moviesLoadFailed = !parsed || movies.isEmpty
    }

    /// improvement: Home's Retry; re-sends the last listing request.
    func retryMovies() {
        guard let request = lastMoviesRequest else { return }
        moviesLoadFailed = false
        Task { try await fetchMovies(page: request.page, filter: request.filter) }
    }

    /// The first page of "last" is the start page itself; every other page is `/page/<n>/?filter=<filter>`.
    func moviesURL(page: Int, filter: String) -> String {
        page == 1 && filter == "last"
            ? "https://\(settingStore)/?filter=last"
            : "https://\(settingStore)/page/\(page)/?filter=\(filter)"
    }

    /// Listing page -> appended to `movies`; also refreshes the premium badge.
    func parse(html: String) throws -> [MovieSimple] {
        let document = try SwiftSoup.parse(html)
        _ = try document.checkPremium()
        document.getMovies()?.forEach { append($0, to: \.movies) }
        return movies
    }

    /// A bookmarks category page -> appended to `bookmarks`.
    func parseBookmarks(html: String) throws -> [MovieSimple] {
        try SwiftSoup.parse(html).getMovies()?.forEach { append($0, to: \.bookmarks) }
        return bookmarks
    }

    /// Full search page -> appended to `search`.
    func parseSearch(html: String) throws -> [MovieSimple] {
        try SwiftSoup.parse(html).getMovies()?.forEach { append($0, to: \.search) }
        return search
    }

    /// `/engine/ajax/search.php/` answer -> appended to `quickSearch`.
    func parseQuickSearch(html: String) throws -> [SearchResult] {
        try SwiftSoup.parse(html).getSearchResults()?.forEach { element in
            var id: String?
            do {
                id = try element.getElementsByTag("a").first()!.attr("href")
            } catch {
                print("error")
            }
            let name = element.getNameSearch()
            let details = element.getDetailsSearch()
            quickSearch.append(SearchResult(id: id!, name: name!, details: details!))
        }
        return quickSearch
    }

    /// One `div.b-content__inline_item` card. Like the original, a card with a missing field traps.
    private func append(_ element: Element, to list: ReferenceWritableKeyPath<Network, [MovieSimple]>) {
        let id = element.getId()
        let title = element.getTitle()
        // getDetails() reads the whole link block ("<title> <year, country, genre>"), so the title is cut off.
        let details = element.getDetails()?.replacingOccurrences(of: "\(title ?? "") ", with: "")
        let poster = element.getPoster()
        // improvement: a film listed again (overlapping pages, a search re-run on reappear) is not added twice.
        guard !self[keyPath: list].contains(where: { $0.id == id }) else { return }
        self[keyPath: list].append(MovieSimple(id: id!, name: title!, details: details!, poster: poster!,
                                               entity: element.coverText("entity"), info: element.coverText("info")))
    }
}

// Qualified: SwiftUI (imported for AppStorage) also declares a `Document` protocol.
private extension SwiftSoup.Document {
    func getMovies() -> Elements? {
        do {
            return try select("div.b-content__inline_item")
        } catch {
            print("error")
            return nil
        }
    }

    func getSearchResults() -> Elements? {
        do {
            guard try body()!.getElementsByClass("b-search__live_section").first()?
                .getElementsByClass("b-search__section_list").first()?.getElementsByTag("li") != nil else { return nil }
            return try body()!.getElementsByClass("b-search__live_section").first()!
                .getElementsByClass("b-search__section_list").first()!.getElementsByTag("li")
        } catch {
            print("error")
            return nil
        }
    }
}

private extension Element {
    /// `data-url` (an absolute page URL) without leading slashes.
    func getId() -> String? {
        do {
            return try String(attr("data-url").drop(while: { $0 == "/" }))
        } catch {
            print("error")
            return nil
        }
    }

    func getTitle() -> String? { linkText(tag: "a") }

    func getDetails() -> String? { linkText(tag: "div") }

    func getPoster() -> String? {
        do {
            return try getElementsByClass("b-content__inline_item-cover").first()!.getElementsByTag("a").first()!
                .getElementsByTag("img").first()!.attr("src")
        } catch {
            print("error")
            return nil
        }
    }

    /// improvement: text of `.<className>` in the card cover ("Сериал", "2 сезон, 8 серия"); nil, never a trap, when absent.
    func coverText(_ className: String) -> String? {
        let text = try? getElementsByClass("b-content__inline_item-cover").first()?.getElementsByClass(className).first()?.text()
        return text?.isEmpty == false ? text : nil
    }

    func getNameSearch() -> String? {
        do {
            return try getElementsByTag("a").first()!.getElementsByClass("enty").first()!.text()
        } catch {
            print("error")
            return nil
        }
    }

    /// The link text without the name and the rating: " (The Matrix, 1999)".
    func getDetailsSearch() -> String? {
        do {
            let rating = try getElementsByTag("a").first()!.getElementsByClass("rating").first()?.text()
            let details = try getElementsByTag("a").first()!.text().replacingOccurrences(of: getNameSearch()!, with: "")
            guard let rating else { return details }
            return details.replacingOccurrences(of: rating, with: "")
        } catch {
            print("error")
            return nil
        }
    }

    /// First `tag` inside `.b-content__inline_item-link`; for "div" that is the link block itself.
    private func linkText(tag: String) -> String? {
        do {
            return try getElementsByClass("b-content__inline_item-link").first()!.getElementsByTag(tag).first()!.text()
        } catch {
            print("error")
            return nil
        }
    }
}

// MARK: - Site request plumbing shared by AccountNetwork, CollectionsNetwork and PeopleNetwork
// The original repeated `AF.request(url, method:, parameters:, encoder:, headers:).responseString`
// inside a checked continuation in every method; these build the same request and await its body.

/// Headers of every site request; most calls also send the form Content-Type, even GETs.
func siteHeaders(version: String, contentType: Bool) -> HTTPHeaders {
    contentType
        ? ["Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
           "X-Hdrezka-Ios-App": "1", "X-Hdrezka-Ios-App-Version": version]
        : ["X-Hdrezka-Ios-App": "1", "X-Hdrezka-Ios-App-Version": version]
}

/// The request Alamofire builds for `AF.request(url, method:, parameters:, encoder: .default, headers:)`:
/// parameters go to the query for GET and to the form body for POST.
func siteRequest(_ url: String, _ method: HTTPMethod = .get, _ parameters: [String: String]? = nil,
                 headers: HTTPHeaders) throws -> URLRequest {
    let request = try URLRequest(url: url, method: method, headers: headers)
    return try parameters.map { try URLEncodedFormParameterEncoder.default.encode($0, into: request) } ?? request
}

/// Sends through Alamofire's shared session (its cookie store keeps the login) and returns the body.
func siteString(_ request: URLRequest) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        // improvement: a non-2xx answer fails with its status code, so error screens can tell 403 and 5xx apart.
        AF.request(request).validate(statusCode: 200..<300).responseString { response in
            switch response.result {
            case .success(let body): continuation.resume(returning: body)
            case .failure(let error): continuation.resume(throwing: error)
            }
        }
    }
}
