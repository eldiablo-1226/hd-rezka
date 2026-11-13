import Foundation
import SwiftSoup

class CollectionsParser: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var moviesInCollections: [MovieSimple] = []
    /// The collections on the page `parseCollections` read last, whether or not the list had them already.
    private(set) var lastPageCount = 0

    /// One page of a collection with the "watching" filter, appended to `moviesInCollections`.
    // shortcut: only this method is known to be main-actor isolated (it hops at entry); whether the whole
    // class was @MainActor like AccountParser is not visible in the binary.
    @MainActor
    func getWatchingNowMoviesInCollection(collectionId: String, page: Int) async throws -> [MovieSimple] {
        let html = try await CollectionsNetwork().getMoviesInCollectionFiltered(id: collectionId, page: page, filter: "watching")
        return try parseMoviesInCollection(html)
    }

    /// Collections list page, appended to `collections`.
    func parseCollections(_ html: String) throws -> [Collection] {
        let items = try SwiftSoup.parse(html).select("div.b-content__collections_item")
        lastPageCount = items.size()
        for item in items {
            let url = try item.attr("data-url")
            // "https://<mirror>/collections/<slug>/" -> "https://<mirror>/<slug>" -> "<slug>"
            let id = String(url.replacingOccurrences(of: "collections/", with: "").dropLast(1))
                .components(separatedBy: "/")[3]
            let name = try item.getName()
            let poster = try item.getElementsByTag("img").first()!.attr("src")
            let count = try item.getCountOfMovies()
            // improvement: a page loaded again (the tab reappearing, a refresh race) adds nothing twice.
            if !collections.contains(where: { $0.id == id }) {
                collections.append(Collection(id: id, name: name, poster: poster, count: count))
            }
        }
        return collections
    }

    /// One collection page, appended to `moviesInCollections`; the id is the card's `data-url`.
    func parseMoviesInCollection(_ html: String) throws -> [MovieSimple] {
        for item in try SwiftSoup.parse(html).select("div.b-content__inline_item") {
            let id = try item.attr("data-url")
            let name = try item.getMovieTitle()
            let details = try item.getMovieDetails().replacingOccurrences(of: name + " ", with: "")
            let poster = try item.getMoviePoster()
            // improvement: a page loaded again (a retry, a reappearance) adds nothing twice.
            guard !moviesInCollections.contains(where: { $0.id == id }) else { continue }
            moviesInCollections.append(MovieSimple(id: id, name: name, details: details, poster: poster))
        }
        return moviesInCollections
    }
}

private extension Element {
    func getName() throws -> String {
        try getElementsByClass("title-layer").first()!.getElementsByTag("a").first()!.text()
    }

    func getCountOfMovies() throws -> Int {
        try Int(getElementsByClass("num hd-tooltip").first()!.text())!
    }

    func getMovieTitle() throws -> String {
        try getElementsByClass("b-content__inline_item-link").first()!.getElementsByTag("a").first()!.text()
    }

    /// The whole link block ("<title> <year, country, genre>"): the block itself is the first "div".
    /// shortcut: name guessed — the compiler merged it into getMovieTitle(), only the tag differs.
    func getMovieDetails() throws -> String {
        try getElementsByClass("b-content__inline_item-link").first()!.getElementsByTag("div").first()!.text()
    }

    func getMoviePoster() throws -> String {
        try getElementsByClass("b-content__inline_item-cover").first()!.getElementsByTag("a").first()!
            .getElementsByTag("img").first()!.attr("src")
    }
}
