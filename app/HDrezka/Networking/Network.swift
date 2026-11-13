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
    /// improvement: the highest listing page in `movies` since the list was last replaced, and whether a page is on its
    /// way. The grids counted pages themselves: a failed page was skipped for good, a failed refresh set the count back
    /// to page 1 under pages 1…N (the next page added nothing and the list stalled), and two pages could be asked at once.
    private(set) var loadedPage = 0
    private(set) var isFetchingPage = false
    /// improvement: a later page failed while the list is on screen: the grid shows «Повторить» under it instead of
    /// asking again by itself (1.6.0 showed nothing, and the list looked finished).
    @Published private(set) var pageFailed = false
    /// The site answered 404 with its own page past the last one: the grid stops asking until a refresh replaces the list.
    @Published private(set) var reachedEnd = false
    /// The cards on the listing page `parse` read last: a page without any (a 403 or 5xx page sent with a body, a block
    /// page, a page past the end) doesn't count as loaded.
    private var pageCards = 0
    /// improvement: the site page this listing pages through for «Каталог» ("films/drama/"); empty for the start page.
    let listingPath: String

    // AccountService creates one off the main actor.
    nonisolated init(listingPath: String = "") {
        self.listingPath = listingPath
    }

    /// Fire-and-forget like the original: returns at once, the page is appended to `movies` when it
    /// arrives. 1.6.0 dropped network and parse errors; they now set `moviesLoadFailed`.
    func fetchMovies(page: Int, filter: String) async throws {
        lastMoviesRequest = (page, filter)
        isFetchingPage = true
        let generation = moviesGeneration
        siteSession.request(moviesURL(page: page, filter: filter), headers: siteHeaders(version: remoteVersion, contentType: false))
            .responseString { response in
                self.receivePage(response.value,
                                 failure: Self.listingFailure(html: response.value, error: response.error,
                                                              statusCode: response.response?.statusCode),
                                 generation: generation, page: page)
            }
    }

    /// improvement: a 404 answered with the site's own page (its header menu is on it) means the site has nothing there,
    /// like an empty «Лучшие» year. A 404 without it comes from a host that isn't a mirror and stays a failure.
    nonisolated static func listingFailure(html: String?, error: Error?, statusCode: Int?) -> PageLoadFailure {
        statusCode == 404 && html?.contains("id=\"topnav-menu\"") == true
            ? .notFound
            : PageLoadFailure(error: error, statusCode: statusCode)
    }

    /// The listing page the grid asks for next: the one after the last in the list, again if it failed.
    var nextPage: Int { loadedPage + 1 }

    /// The Retry row under the grid: the page that failed, again.
    func retryNextPage() {
        guard !isFetchingPage else { return }  // a refresh is on its way; its answer decides
        pageFailed = false
        fetchNextPage()
    }

    /// The grid's paging cell: the next page of the last listing asked for, one at a time.
    func fetchNextPage() {
        guard !isFetchingPage, let filter = lastMoviesRequest?.filter else { return }
        isFetchingPage = true  // now: a second trigger in this turn must not pass the guard
        Task { try await fetchMovies(page: nextPage, filter: filter) }
    }

    /// Starts over from page 1 without clearing the list: the caller fetches page 1, which then replaces it. A list
    /// already emptied (another listing) starts its count over too.
    func beginRefresh() {
        moviesGeneration += 1
        replaceOnNextPage = true
        moviesLoadFailed = false
        if movies.isEmpty {
            loadedPage = 0
            reachedEnd = false
        }
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
        defer {
            isFetchingPage = false
            resumePageWaiters()
        }
        if replaceOnNextPage && (page ?? 1) == 1 {
            replaceOnNextPage = false
            let previous = movies
            movies = []
            if html.flatMap({ try? parse(html: $0) }) == nil || movies.isEmpty {
                movies = previous
                moviesRefreshFailed = !previous.isEmpty
                moviesLoadFailed = previous.isEmpty
            } else {
                loadedPage = 1
                pageFailed = false
                reachedEnd = false
            }
            return
        }
        let parsed = html.flatMap { try? parse(html: $0) } != nil
        if parsed && pageCards > 0 {
            loadedPage = max(loadedPage, page ?? 1)
            pageFailed = false
        } else if !movies.isEmpty {
            // The site's own 404 past the last page is the list's end.
            reachedEnd = moviesLoadFailure == .notFound
            pageFailed = !reachedEnd
        }
        moviesLoadFailed = !parsed || movies.isEmpty
    }

    /// improvement: Home's Retry; re-sends the last listing request.
    func retryMovies() {
        guard let request = lastMoviesRequest else { return }
        moviesLoadFailed = false
        Task { try await fetchMovies(page: request.page, filter: request.filter) }
    }

    /// The first page of "last" is the start page itself; every other page is `/page/<n>/?filter=<filter>`.
    /// A «Каталог» listing is its path, then `page/<n>/` from page 2; it takes no filter.
    func moviesURL(page: Int, filter: String) -> String {
        if !listingPath.isEmpty {
            return "https://\(settingStore)/\(listingPath)" + (page == 1 ? "" : "page/\(page)/")
        }
        return page == 1 && filter == "last"
            ? "https://\(settingStore)/?filter=last"
            : "https://\(settingStore)/page/\(page)/?filter=\(filter)"
    }

    /// Listing page -> appended to `movies`; also refreshes the premium badge.
    func parse(html: String) throws -> [MovieSimple] {
        let document = try SwiftSoup.parse(html)
        _ = try document.checkPremium()
        let cards = document.getMovies()
        pageCards = cards?.size() ?? 0
        cards?.forEach { append($0, to: \.movies) }
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
    /// improvement: only the leading name and the trailing rating are cut; 1.6.0 cut them out of the whole line, so
    /// «1984 (Nineteen Eighty-Four, 1984)» lost its year.
    func getDetailsSearch() -> String? {
        do {
            let link = try getElementsByTag("a").first()!
            let rating = try link.getElementsByClass("rating").first()?.text()
            var details = try link.text()
            if let name = getNameSearch(), details.hasPrefix(name) { details.removeFirst(name.count) }
            if let rating, details.hasSuffix(rating) { details.removeLast(rating.count) }
            return details
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

/// improvement: how long a site request may go without data before it fails. 1.6.0 used Alamofire's 60 s, so a mirror
/// that silently dropped traffic kept the shimmer or the spinner for a minute; its error screen now comes after 15 s.
let siteTimeout: TimeInterval = 15

/// The request with the site timeout; `siteSession` applies it to every request it sends.
func withSiteTimeout(_ request: URLRequest) -> URLRequest {
    var request = request
    request.timeoutInterval = siteTimeout
    return request
}

/// improvement (critique r1): how long a site request may take in all. `siteTimeout` counts only a silence, so a mirror
/// that kept trickling its answer held the page's orb for over a minute; past this the request fails as timed out and
/// PageLoadFailedView offers «Сменить зеркало» and «Повторить».
let siteDeadline: TimeInterval = 30

/// Every site request goes through this session: Alamofire's defaults (the shared cookie store, so the login carries
/// over, and the User-Agent the mirrors expect) plus the site timeout and deadline.
let siteSession: Session = {
    let configuration = URLSessionConfiguration.af.default
    configuration.timeoutIntervalForResource = siteDeadline
    return Session(configuration: configuration,
                   interceptor: Adapter { request, _, completion in completion(.success(withSiteTimeout(request))) })
}()

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
        siteSession.request(request).validate(statusCode: 200..<300).responseString { response in
            switch response.result {
            case .success(let body): continuation.resume(returning: body)
            case .failure(let error): continuation.resume(throwing: error)
            }
        }
    }
}
