import Foundation
import SwiftSoup

/// Main-actor isolated as in the binary: its init and methods run after a hop to the main actor.
@MainActor
class AccountParser: ObservableObject {
    @Published var watchingLaterMovies: [MovieWatchLater] = []
    @Published var seriesUpdates: [SeriesUpdateGroup] = []

    /// Start-page sidebar -> one group per day that has followed (`.tracked`) series, appended to `seriesUpdates`.
    func parseSeriesUpdates(html: String) throws -> [SeriesUpdateGroup] {
        try SwiftSoup.parse(html).select("div.b-seriesupdate__block").forEach { block in
            let date = try block.select("div.b-seriesupdate__block_date").text()
                .replacingOccurrences(of: "развернуть", with: "")
            var releasedEpisodes: [SeriesUpdateItem] = []
            for item in try block.select("li.b-seriesupdate__block_list_item.tracked") {
                let id = try "https://ijobs.app" + item.select("a.b-seriesupdate__block_list_link").attr("href")
                let seriesName = try item.select("a.b-seriesupdate__block_list_link").text()
                let season = try item.select("span.season").text()
                let cell = try item.select("span.cell.cell-2")
                let releasedEpisode = try cell.text().replacingOccurrences(of: cell.select("i").text(), with: "")
                let chosenVoiceActing = try item.select("span.cell.cell-2").select("i").text()
                releasedEpisodes.append(SeriesUpdateItem(id: id, seriesName: seriesName, season: season,
                                                         releasedEpisode: releasedEpisode,
                                                         chosenVoiceActing: chosenVoiceActing))
            }
            if !releasedEpisodes.isEmpty {
                seriesUpdates.append(SeriesUpdateGroup(date: date, releasedEpisodes: releasedEpisodes))
            }
        }
        return seriesUpdates
    }

    /// "Continue watching" page, appended to `watchingLaterMovies`.
    func parseWatchingLaterMovies() async throws -> [MovieWatchLater] {
        let html = try await AccountNetwork().getWatchingLaterMovies()
        return try parseWatchingLaterMovies(html: html)
    }

    /// The HTML half of `parseWatchingLaterMovies()` (inline in the original).
    func parseWatchingLaterMovies(html: String) throws -> [MovieWatchLater] {
        for item in try SwiftSoup.parse(html).getWatchingLaterMovies() {
            let id = try item.getId()
            let name = try item.getElementsByClass("td title").first()!.getElementsByTag("a").text()
            let details = try item.getElementsByClass("td title").first()!.getElementsByTag("small").text()
            let info = try item.getElementsByClass("td info").first()!
            let watchingInfo = try info.text()
                .replacingOccurrences(of: info.getElementsByTag("span").first()?.text() ?? "", with: "")
            let date = try item.getElementsByClass("td date").text()
            let buttonText = try item.getButtonText()
            let dataId = try item.select("a.i-sprt.delete").first()!.attr("data-id")
            watchingLaterMovies.append(MovieWatchLater(id: id, name: name, details: details, watchingInfo: watchingInfo,
                                                       date: date, buttonText: buttonText, dataId: dataId))
        }
        return watchingLaterMovies
    }

    /// Answer of quick_register.php: success is a script that reloads the page (or an empty script).
    func checkRegistration(html: String) throws -> Bool {
        guard let script = try SwiftSoup.parse(html).select("script").first() else { return false }
        let code = try script.html()
        return code.contains("location") || code.isEmpty
    }

    /// Bookmark categories; the id is the number after the last "-" of the element id.
    func parseBookmarks(html: String) throws -> [Bookmark] {
        try SwiftSoup.parse(html).select("div.b-favorites_content__cats_list_item").map { element in
            let dash = element.id().lastIndex(of: "-")!
            let id = Int(element.id()[element.id().index(after: dash)...])!
            return try Bookmark(id: id, name: element.select("span.name").text())
        }
    }

    /// Answer of registration.php: the name / e-mail is free when it contains `span.string-ok`.
    /// shortcut: name guessed — the original method was inlined into AccountService.checkEmail/checkUsername
    /// (it runs on this main-actor parser there) and its symbol stripped.
    func checkAvailability(html: String) throws -> Bool {
        try !SwiftSoup.parse(html).select("span.string-ok").isEmpty()
    }
}

private extension Document {
    /// The first list item is the table header.
    func getWatchingLaterMovies() throws -> [Element] {
        let items = try select("div.b-videosaves__list_item")
        if items.isEmpty() {
            return items.array()
        }
        var array = items.array()
        array.removeFirst()
        return array
    }
}

private extension Element {
    /// "Watch next episode" link text of the info cell, nil when there is none.
    func getButtonText() throws -> String? {
        guard let spans = try getElementsByClass("td info").first()?.getElementsByTag("span"),
              !spans.array().isEmpty else { return nil }
        return try spans.text()
    }

    func getId() throws -> String {
        try getElementsByClass("td title").first()!.getElementsByTag("a").first()!.attr("href")
    }
}
