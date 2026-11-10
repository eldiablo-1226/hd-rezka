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

    nonisolated init() {}  // AccountService creates one off the main actor

    /// Fire-and-forget like the original: returns at once, the page is appended to `movies` when it
    /// arrives (network and parse errors are dropped).
    func fetchMovies(page: Int, filter: String) async throws {
        AF.request(moviesURL(page: page, filter: filter), headers: siteHeaders(version: remoteVersion, contentType: false))
            .responseString { response in self.receivePage(response.value) }
    }

    /// The arrived listing page, parsed in a new task (on the main actor, like everything here).
    func receivePage(_ html: String?) {
        Task {
            if let html {
                _ = try? self.parse(html: html)  // the original's throwing task dropped the error too
            }
        }
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
        self[keyPath: list].append(MovieSimple(id: id!, name: title!, details: details!, poster: poster!))
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
        AF.request(request).responseString { response in
            switch response.result {
            case .success(let body): continuation.resume(returning: body)
            case .failure(let error): continuation.resume(throwing: error)
            }
        }
    }
}
