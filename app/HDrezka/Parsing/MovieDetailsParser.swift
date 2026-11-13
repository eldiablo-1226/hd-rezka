import Foundation
import SwiftSoup
import SwiftUI

/// Episode and season labels lose everything except digits and ASCII punctuation ("Сезон 1" -> "1"),
/// but only where the binary passes `.regularExpression` (parseSeriesSeasons); getSeasons() passes no options.
private let nonDigitRun = "[^\\d!-/:-@\\[-`{-~]+"

/// improvement: what a movie or person page lacks when it cannot be shown at all (1.6.0 trapped there instead of
/// throwing). The error screen tells it apart from network problems (`PageLoadFailure.unparsable`).
struct PageParseError: Error { let missing: String }

class MovieDetailsParser: ObservableObject {
    @Published var movieDetailed: [MovieDetailed] = []
    @Published var movieSeason: [MovieSeason] = []

    /// Appends the page to `movieDetailed` and returns the whole list (the original never clears it).
    func parseMovieDetails(html: String, movieId: String) throws -> [MovieDetailed] {
        let doc = try SwiftSoup.parse(html)
        // improvement: required, so a page without the movie block or its title throws (details Retry state); 1.6.0 trapped.
        guard let main = try doc.select("div.b-content__main").first(),
              let nameRussian = try main.getElementsByClass("b-post__title").first()?.text()
        else { throw PageParseError(missing: "div.b-content__main .b-post__title") }
        let nameOriginal = try main.getElementsByClass("b-post__origtitle").first()?.text()
        let poster = try main.getDetailsPoster()
        let hPoster = try main.getDetailsHPoster()
        let description = try main.getDescription()
        let isAvailable = doc.isAvailable()
        let isComingSoon = doc.isComingSoon()
        var seasons: [MovieSeason]?
        var voiceActing: [MovieVoiceActing]?
        if isAvailable, !isComingSoon {
            seasons = try doc.getSeasons()
            voiceActing = try doc.getVoiceActing(movieId: movieId)
        }
        let schedule = try doc.getSchedule()
        let franchise = try doc.getFranchise()
        let voiceActingRating = isComingSoon ? nil : try doc.getVoiceActingRating()
        let commentsCount = try doc.getCommentsCount()

        var imdbRating: Float?, imdbVotes: String?, imdbLink: String?
        var kpRating: Float?, kpVotes: String?, kpLink: String?
        var releaseDate: String?, producer: [PersonSimple]?, ageRestriction: String?, country: String?
        var genres: [MovieGenre]?, duration: String?, lists: [MovieList]?, collections: [String: String]?
        var singleVoiceActingName: String?, actors: [PersonSimple]?
        main.getDetailsChunked { chunk in
            do {
                // improvement: a one-cell row (the cast) never matches a label, so a label without its value cell cannot trap on chunk[1].
                switch try chunk.count > 1 ? chunk[0].getElementsByTag("h2").text() : "" {
                case "Рейтинги":
                    imdbRating = chunk.getImdbRating()
                    imdbVotes = chunk.getImdbVotes()
                    imdbLink = try chunk.getImdbLink()
                    kpRating = try chunk.getKpRating()
                    kpVotes = chunk.getKpVotes()
                    kpLink = try chunk.getKpLink()
                case "Дата выхода":
                    releaseDate = try chunk[1].text()
                case "Режиссер":
                    producer = try chunk.getProducers()
                case "Возраст":
                    // improvement: no span gives nil, then the "0+" of a page without the row (1.6.0 trapped).
                    ageRestriction = try chunk[1].getElementsByTag("span").first()?.text()
                case "Страна":
                    country = try chunk[1].text()
                case "Жанр":
                    genres = try chunk[1].getElementsByTag("a").map { MovieGenre(id: try $0.attr("href"), name: try $0.text()) }
                case "Время":
                    duration = try chunk[1].text()
                case "Входит в списки":
                    lists = try chunk[1].getMovieLists()
                case "Из серии":
                    // key: the collection link without "collections/" and its trailing "/", value: its title
                    var found: [String: String] = [:]
                    for link in try chunk[1].getElementsByTag("a") {
                        let key = String(try link.attr("href").replacingOccurrences(of: "collections/", with: "").dropLast())
                        found[key] = try link.text()
                    }
                    collections = found
                case "В переводе":
                    singleVoiceActingName = try chunk[1].text()
                default:
                    if let cast = chunk.getActors() { actors = cast }
                }
            } catch {
                print("error in parseMovieDetails")
            }
        }
        let bookmarks = try doc.getBookmarks()

        func rating(_ value: Float?, _ votes: String?, _ link: String?) -> MovieRating? {
            guard let value, let votes, let link else { return nil }
            return MovieRating(value: value, votesCount: votes, link: link)
        }
        movieDetailed.append(MovieDetailed(
            id: "", nameRussian: nameRussian, nameOriginal: nameOriginal, poster: poster, hPoster: hPoster,
            duration: duration ?? "nil", description: description, releaseDate: releaseDate,
            country: country ?? "nil", ageRestriction: ageRestriction ?? "0+",
            imdbRating: rating(imdbRating, imdbVotes, imdbLink), kpRating: rating(kpRating, kpVotes, kpLink),
            // improvement: no «Жанр» row gives no genres (1.6.0 trapped on genres!); the details views take prefix(1).
            genres: genres ?? [], lists: lists, collections: collections, schedule: schedule, franchise: franchise,
            producer: producer, actors: actors, ytTrailerLink: nil, ytTrailerPreview: nil,
            availability: isAvailable ? .AVAILABLE_ON_REZKA : .UNAVAILABLE, comingSoon: isComingSoon,
            voiceActing: voiceActing, singleVoiceActingName: singleVoiceActingName, voiceActingRating: voiceActingRating,
            seasons: seasons, video: nil, bookmarks: bookmarks, commentsCount: commentsCount))
        return movieDetailed
    }

    /// A page (voice acting with its own URL) goes through getSeasons(); otherwise `html` is the get_episodes JSON
    /// whose "seasons"/"episodes" HTML is appended to `movieSeason`, which is then returned.
    func parseSeriesSeasons(_ html: String) -> [MovieSeason]? {
        if let seasons = try? SwiftSoup.parse(html).getSeasons() {
            return seasons
        }
        do {
            guard let data = html.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let seasonsHtml = json["seasons"] as? String,
                  let episodesHtml = json["episodes"] as? String else { return nil }
            for season in try SwiftSoup.parse(seasonsHtml).body()?.select(".b-simple_season__item") ?? Elements() {
                let id = try season.attr("data-tab_id")
                let name = try season.text().replacingOccurrences(of: nonDigitRun, with: "", options: .regularExpression)
                let isSelected = try season.attr("class").contains("active")
                let url = season.hasAttr("href") ? try season.attr("href") : nil
                let items = try SwiftSoup.parse(episodesHtml).body()?.select(".b-simple_episode__item[data-season_id=" + id + "]") ?? Elements()
                let episodes = try items.map { try $0.episode(.regularExpression) }
                movieSeason.append(MovieSeason(id: id, name: name, episodes: episodes, isSelected: isSelected, url: url))
            }
            return movieSeason
        } catch {
            print("error in parseSeriesSeasons")
            return nil
        }
    }

    /// gettrailervideo.php answers {"code": "<iframe src=\"https://www.youtube.com/embed/<id>?…\">"}.
    func parseTrailerId(response: String) throws -> String? {
        guard let data = response.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any],
              let code = json["code"] as? String,
              let src = try SwiftSoup.parse(code).getElementsByTag("iframe").first()?.attr("src") else { return nil }
        return src.replacingOccurrences(of: "https://www.youtube.com/embed/", with: "").components(separatedBy: "?").first
    }
}

// SwiftUI (for @AppStorage) also declares a `Document`, hence the module prefix.
extension SwiftSoup.Document {
    /// Reads the signed-in account's premium badge into the "hasPremium" AppStorage value ("" for guests).
    /// improvement: a page without the badge clears it only when it is the site's own (its header menu): a 403, 5xx or
    /// block page read as "no premium" and locked premium voice actings until the next good page.
    func checkPremium() throws -> SwiftSoup.Document {
        @AppStorage("hasPremium") var hasPremium: String = ""
        // improvement: a document without <body> counts as a guest ("") instead of trapping.
        let badge = try body()?.select(".b-tophead-premuser").select("b").text() ?? ""
        let isSitePage = try !select("#topnav-menu").isEmpty()
        if !badge.isEmpty || isSitePage { hasPremium = badge }
        return self
    }

    func isAvailable() -> Bool {
        do {
            return try select("div.b-player__restricted").isEmpty()
        } catch {
            print("error in isAvailable")
            return false
        }
    }

    func isComingSoon() -> Bool {
        do {
            return try !select("div.b-post__status_logo").isEmpty()
        } catch {
            print("error in isComingSoon")
            return false
        }
    }

    /// Season tabs with their episode lists; a single-season page (episodes but no tabs) becomes "Сезон <id>".
    func getSeasons() throws -> [MovieSeason]? {
        let noSeasons = try select("ul#simple-seasons-tabs").isEmpty()
        let noEpisodes = try select("div#simple-episodes-tabs").isEmpty()
        if !noSeasons {
            return try getElementsByClass("b-simple_season__item").map { season in
                let id = try season.attr("data-tab_id")
                // improvement: a tab without its episode list keeps the season with no episodes (1.6.0 trapped); the sheets cope.
                let episodes = try select("ul#simple-episodes-list-" + id).first()?
                    .getElementsByClass("b-simple_episode__item").map { try $0.episode() } ?? []
                return MovieSeason(id: id, name: try season.text().replacingOccurrences(of: nonDigitRun, with: ""), episodes: episodes,
                                   isSelected: try season.attr("class").contains("active"),
                                   url: season.hasAttr("href") ? try season.attr("href") : nil)
            }
        }
        if !noEpisodes {
            // improvement: no episode at all reads as no seasons, a season id without its list as no episodes (1.6.0 trapped).
            guard let id = try select("ul[id*=\"simple-episodes-list\"]").first()?
                .getElementsByClass("b-simple_episode__item").first()?.attr("data-season_id") else { return nil }
            let episodes = try select("ul#simple-episodes-list-" + id).first()?
                .getElementsByClass("b-simple_episode__item").map { try $0.episode() } ?? []
            return [MovieSeason(id: id, name: ("Сезон " + id).replacingOccurrences(of: nonDigitRun, with: ""), episodes: episodes,
                                isSelected: true, url: nil)]
        }
        return nil
    }

    func getVoiceActing(movieId: String) throws -> [MovieVoiceActing] {
        /// No translator list: the only voice acting is the second argument of initCDN{Movies,Series}Events(id, translator, …).
        func getByOffset() throws -> [MovieVoiceActing] {
            let page = description
            let call = page.contains("initCDNMoviesEvents") ? "initCDNMoviesEvents" : "initCDNSeriesEvents"
            // improvement: required on a playable page (the play and download sheets index into it), so no call throws; 1.6.0 trapped.
            let arguments = page.range(of: call).map { page[$0.upperBound...].split(separator: ", ") } ?? []
            guard arguments.count > 1 else { throw PageParseError(missing: call) }
            return [MovieVoiceActing(id: movieId, name: "", translatorId: String(arguments[1]), isCamrip: "", isAds: "",
                                     isDirector: "", isSelected: true, isPremium: false, url: nil)]
        }
        let list = try select("ul#translators-list")
        if list.isEmpty() { return try getByOffset() }
        return try list.first()!.getElementsByClass("b-translator__item").map { item in
            var name = try item.text()
            if let flag = try item.select("img").first() {
                name += try flag.attr("title").languageFlag
            }
            return MovieVoiceActing(id: movieId, name: name,
                                    translatorId: try item.attr("data-translator_id"),
                                    isCamrip: try item.attr("data-camrip"),
                                    isAds: try item.attr("data-ads"),
                                    isDirector: try item.attr("data-director"),
                                    isSelected: try item.attr("class").contains("active"),
                                    isPremium: item.hasClass("b-prem_translator"),
                                    url: item.hasAttr("href") ? try item.attr("href") : nil)
        }
    }

    func getSchedule() throws -> [SeriesScheduleGroup]? {
        if try select("div.b-post__schedule_block").isEmpty() { return nil }
        return try select("div.b-post__schedule_block").map { block in
            let name = try block.select("div.b-post__schedule_block_title").select("div.title").text()
            let items = try block.select("tr").compactMap { row -> SeriesScheduleItem? in
                let title = try row.select("td.td-1").text()
                let russianEpisodeName = try row.select("td.td-2").select("b").text()
                let originalEpisodeName = try row.select("td.td-2").select("span").text()
                let releaseDate = try row.select("td.td-4").text()
                return SeriesScheduleItem(title: title, russianEpisodeName: russianEpisodeName,
                                          originalEpisodeName: originalEpisodeName.isEmpty ? nil : originalEpisodeName,
                                          releaseDate: releaseDate)
            }
            return SeriesScheduleGroup(name: name, items: items)
        }
    }

    func getFranchise() throws -> [MovieFranchisePart]? {
        if try select("div.b-post__partcontent_item").isEmpty() { return nil }
        return try select("div.b-post__partcontent_item").compactMap { item -> MovieFranchisePart? in
            let name = try item.select("div.td.title").text()
            let id = try item.attr("data-url")
            let year = try item.select("div.td.year").text()
            let rating = Float(try item.select("div.td.rating").text())
            let current = item.hasClass("current")
            let position = Int(try item.select("div.td.num").text()) ?? 0
            return MovieFranchisePart(id: id, name: name, year: year, rating: rating, current: current, position: position)
        }
    }

    /// The popularity tooltip: one entry per voice acting row ("лостфильм (LostFilm)", 98.49).
    /// improvement: the original mapped the whole `div.inner` list in one go, so all rows ended up in a single entry
    /// (joined titles, and percent 0 as soon as there was more than one row); the page's voice acting rows show these.
    func getVoiceActingRating() throws -> [MovieVoiceActingRating]? {
        guard let help = try select("span.b-rgstats__help").first() else { return nil }
        let title = try Entities.unescape(try help.attr("title"))
        guard let rows = try SwiftSoup.parse(title).body()?.select("div.inner"), !rows.isEmpty() else { return nil }
        return try rows.map { row in
            let percent = try row.select("div.count").text().replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".")
            let language = try row.select("img").first()?.attr("title") ?? ""
            let name = try row.select("div.title").text() + language.languageFlag
            return MovieVoiceActingRating(name: name, percent: Float(percent) ?? 0)
        }
    }

    func getCommentsCount() throws -> Int {
        Int(try select("button#comments-list-button").select("em").text()) ?? 0
    }

    /// Bookmark folders of the signed-in user and whether this title is in each ("Name (count)" -> "Name ").
    func getBookmarks() throws -> [Bookmark: Bool] {
        var bookmarks: [Bookmark: Bool] = [:]
        for row in try select("div#user-favorites-list").select("div.hd-label-row") {
            let name = try row.getElementsByTag("label").text().components(separatedBy: "(").first ?? ""
            let id = Int(try row.getElementsByTag("input").attr("value")) ?? 0
            bookmarks[Bookmark(id: id, name: name)] = try row.getElementsByTag("input").hasAttr("checked")
        }
        return bookmarks
    }
}

extension Element {
    /// improvement: `data-photo` of the enclosing `span.person-name-item`; the site writes "null" when there is none.
    func personPhoto() -> String? {
        guard let photo = try? parent()?.attr("data-photo"), photo.hasPrefix("http") else { return nil }
        return photo
    }

    // improvement: no sidecover gives "" (the views and the player read an empty URL as no image); 1.6.0 trapped.
    func getDetailsPoster() throws -> String {
        try select("div.b-sidecover").first()?.getElementsByTag("a").first()?.getElementsByTag("img").first()?.attr("src") ?? ""
    }

    // improvement: likewise "" without a sidecover.
    func getDetailsHPoster() throws -> String {
        try select("div.b-sidecover").first()?.getElementsByTag("a").first()?.attr("href") ?? ""
    }

    // improvement: no description gives "" (MovieDetailed.description is not optional); 1.6.0 trapped.
    func getDescription() throws -> String {
        try getElementsByClass("b-post__description").first()?.getElementsByClass("b-post__description_text").first()?.text() ?? ""
    }

    /// The "Входит в списки" cell: "<a href=…>Лучшие боевики 2012 года</a> (19 место)<br>…".
    func getMovieLists() throws -> [MovieList] {
        // improvement: a part without a link is dropped and a missing "(N место)" gives position 0 (1.6.0 trapped on both).
        try outerHtml().split(separator: "<br>").compactMap { part -> MovieList? in
            guard let body = try SwiftSoup.parse(String(part)).body(), let link = try body.getElementsByTag("a").first() else { return nil }
            let position = try body.text().split(separator: "(").dropFirst().last?.components(separatedBy: " ").dropLast().joined()
            return MovieList(id: try link.attr("href"), name: try link.text(), moviePosition: position.flatMap { Int($0) } ?? 0)
        }
    }

    /// Calls `onGot` with the cells of every info-table row, two at a time ([label, value]; the cast row has one cell).
    func getDetailsChunked(onGot: @escaping ([Element]) -> ()) {
        do {
            // improvement: no info table means no rows, so every info field keeps its default (1.6.0 trapped).
            for tbody in try select("table.b-post__info").first()?.getElementsByTag("tbody") ?? Elements() {
                for row in try tbody.getElementsByTag("tr") {
                    let cells = try row.getElementsByTag("td").array()
                    for start in stride(from: 0, to: cells.count, by: 2) {
                        onGot(Array(cells[start ..< min(start + 2, cells.count)]))
                    }
                }
            }
        } catch {
            print("error getting chunked details")
        }
    }

    fileprivate func episode(_ options: String.CompareOptions = []) throws -> MovieEpisode {
        MovieEpisode(id: try attr("data-episode_id"),
                     name: try text().replacingOccurrences(of: nonDigitRun, with: "", options: options),
                     isSelected: try attr("class").contains("active"),
                     url: hasAttr("href") ? try attr("href") : nil)
    }
}

/// Info-table chunks from getDetailsChunked: self[0] is the label cell, self[1] the value cell.
extension Array where Element == SwiftSoup.Element {
    func getImdbRating() -> Float? {
        do {
            guard let rates = try self[1].getElementsByClass("b-post__info_rates imdb").first(),
                  let bold = try rates.getElementsByClass("bold").first() else { return nil }
            return Float(try bold.text())
        } catch {
            print("error getting Imdb rating")
            return nil
        }
    }

    func getImdbVotes() -> String? {
        do {
            guard let rates = try self[1].getElementsByClass("b-post__info_rates imdb").first(),
                  let votes = try rates.getElementsByTag("i").first() else { return nil }
            return try votes.text().toShortNumber()
        } catch {
            print("error getting Imdb votes")
            return nil
        }
    }

    func getImdbLink() throws -> String? {
        guard let rates = try self[1].getElementsByClass("b-post__info_rates imdb").first(),
              let link = try rates.getElementsByTag("a").first() else { return nil }
        return try link.attr("href").decodedHelpLink()
    }

    /// Unlike getImdbRating, a missing kp span or .bold parses "0" (0x1000beae0), so the result is 0, not nil.
    func getKpRating() throws -> Float? {
        Float(try self[1].getElementsByClass("b-post__info_rates kp").first()?.getElementsByClass("bold").first()?.text() ?? "0")
    }

    func getKpVotes() -> String? {
        do {
            guard let rates = try self[1].getElementsByClass("b-post__info_rates kp").first(),
                  let votes = try rates.getElementsByTag("i").first() else { return nil }
            return try votes.text().toShortNumber()
        } catch {
            print("error getting kp votes")
            return nil
        }
    }

    func getKpLink() throws -> String? {
        guard let rates = try self[1].getElementsByClass("b-post__info_rates kp").first(),
              let link = try rates.getElementsByTag("a").first() else { return nil }
        return try link.attr("href").decodedHelpLink()
    }

    // improvement: a director cell without persons-list-holder gives nil, as if the row were absent (1.6.0 trapped).
    func getProducers() throws -> [PersonSimple]? {
        try self[1].getElementsByClass("persons-list-holder").first()?.select("a")
            .map { PersonSimple(id: try $0.attr("href"), name: try $0.text(), photo: $0.personPhoto()) }
    }

    /// Any row that is not one of the known labels: the cast row keeps its people in a div.
    func getActors() -> [PersonSimple]? {
        do {
            let holders = try self[0].getElementsByTag("div")
            if holders.isEmpty() { return nil }
            var actors: [PersonSimple] = []
            for link in try holders.select("a") {
                actors.append(PersonSimple(id: try link.attr("href"), name: try link.text(), photo: link.personPhoto()))
            }
            return actors
        } catch {
            print("error getting actors")
            return nil
        }
    }
}

private extension String {
    /// "/help/<base64 of the percent-encoded URL>/" -> the URL ("" when the base64 does not decode).
    func decodedHelpLink() -> String? {
        let path = String(reversed().drop { $0 == "/" }.reversed())
        // improvement: an href without the /help/ wrapper is already the URL, so the rating keeps it (1.6.0 trapped).
        guard let help = path.range(of: "/help/", options: .backwards) else { return self }
        let encoded = String(path[help.upperBound...])
        return (Data(base64Encoded: encoded).flatMap { String(data: $0, encoding: .utf8) } ?? "").removingPercentEncoding
    }

    /// The flag appended to Ukrainian and Kazakh voice actings, keyed by the flag image's title.
    /// improvement: a no-break space before it, so at large text sizes the flag never wraps onto a line of its own.
    var languageFlag: String {
        switch self {
        case "Украинский": "\u{00A0}🇺🇦"
        case "Казахский": "\u{00A0}🇰🇿"
        default: ""
        }
    }
}
