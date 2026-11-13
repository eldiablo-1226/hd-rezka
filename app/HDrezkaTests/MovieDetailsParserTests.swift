import XCTest
import SwiftSoup
@testable import HDrezka

/// Fixtures are real hdrezka.ag pages from the Wayback Machine (ijobs.app answers 403 to guests on
/// detail pages). The archive crawler is region-blocked, so both pages carry div.b-player__restricted.
final class MovieDetailsParserTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var film: String { get throws { try fixture("details-film-hunger-games.html") } }
    private var series: String { get throws { try fixture("details-series-hawaii.html") } }

    // MARK: parseMovieDetails

    func testFilmDetails() throws {
        let parser = MovieDetailsParser()
        let details = try parser.parseMovieDetails(html: film, movieId: "205")
        XCTAssertEqual(details.count, 1)
        XCTAssertEqual(parser.movieDetailed.count, 1)
        let d = try XCTUnwrap(details.first)

        XCTAssertEqual(d.id, "")
        XCTAssertEqual(d.nameRussian, "Голодные игры")
        XCTAssertEqual(d.nameOriginal, "The Hunger Games")
        XCTAssertEqual(d.poster, "https://static.hdrezka.ac/i/2013/7/16/k3f61f25aee23ol86r99n.jpg")
        XCTAssertEqual(d.hPoster, "https://static.hdrezka.ac/i/2013/7/16/p3f61f25aee23sr84q51w.jpg")
        XCTAssertTrue(d.description.hasPrefix("Действия фильма происходят в далеком будущем"), d.description)
        XCTAssertEqual(d.duration, "144 мин.")
        XCTAssertEqual(d.releaseDate, "12 марта 2012 года")
        XCTAssertEqual(d.country, "США")
        XCTAssertEqual(d.ageRestriction, "12+")

        XCTAssertEqual(d.imdbRating?.value, 7.2)
        XCTAssertEqual(d.imdbRating?.votesCount, "1,4M", "<i>(1 043 261)</i>: the binary takes the first digit of n % 1 000 000")
        XCTAssertEqual(d.imdbRating?.link, "https://www.imdb.com/title/tt1392170/")
        XCTAssertEqual(d.kpRating?.value, 7.27)
        XCTAssertEqual(d.kpRating?.votesCount, "503K")
        XCTAssertEqual(d.kpRating?.link, "https://www.kinopoisk.ru/film/468581/")

        XCTAssertEqual(d.genres.map(\.name), ["Боевики", "Приключения", "Фантастика", "Драмы", "Триллеры", "Зарубежные"])
        XCTAssertEqual(d.genres.first?.id, "https://hdrezka.ag/films/action/")

        XCTAssertEqual(d.lists?.count, 6)
        XCTAssertEqual(d.lists?.first?.id, "https://hdrezka.ag/films/best/action/2012/")
        XCTAssertEqual(d.lists?.first?.name, "Лучшие боевики 2012 года")
        XCTAssertEqual(d.lists?.first?.moviePosition, 19)
        XCTAssertEqual(d.lists?.last?.name, "Лучшие зарубежные фильмы 2012 года")
        XCTAssertEqual(d.lists?.last?.moviePosition, 140)

        XCTAssertEqual(d.collections?.count, 5)
        XCTAssertEqual(d.collections?["https://hdrezka.ag/317-ekranizacii-literaturnyh-proizvedeniy"], "Экранизации литературных произведений")

        XCTAssertEqual(d.producer?.map(\.name), ["Гэри Росс"])
        XCTAssertEqual(d.producer?.first?.id, "https://hdrezka.ag/person/4174-geri-ross/")
        XCTAssertEqual(d.actors?.first?.name, "Дженнифер Лоуренс")
        XCTAssertEqual(d.actors?.first?.id, "https://hdrezka.ag/person/2784-dzhennifer-lourens/")

        XCTAssertEqual(d.singleVoiceActingName,
                       "Дубляж, Матвеев, Украинский дубляж, Украинский (1+1), Грузинский двухголосый, Белорусский многоголосый и Оригинал (+субтитры)")
        XCTAssertEqual(d.availability, .UNAVAILABLE)
        XCTAssertFalse(d.comingSoon)
        XCTAssertNil(d.voiceActing, "restricted pages skip voice actings")
        XCTAssertNil(d.seasons)
        XCTAssertNil(d.video)
        XCTAssertNil(d.ytTrailerLink)
        XCTAssertNil(d.ytTrailerPreview)
        XCTAssertNil(d.schedule)
        XCTAssertNil(d.voiceActingRating)
        XCTAssertEqual(d.franchise?.count, 5)
        XCTAssertEqual(d.bookmarks, [:])
        XCTAssertEqual(d.commentsCount, 539)
    }

    func testSeriesDetailsOnAvailablePage() throws {
        // Same page without the region block: the parser then also reads seasons and voice actings.
        let html = try series.replacingOccurrences(of: "b-player__restricted", with: "b-player__open")
        let d = try XCTUnwrap(MovieDetailsParser().parseMovieDetails(html: html, movieId: "1605").first)

        XCTAssertEqual(d.nameRussian, "Гавайи 5.0 / Полиция Гавайев")
        XCTAssertEqual(d.nameOriginal, "Hawaii Five-0")
        XCTAssertEqual(d.availability, .AVAILABLE_ON_REZKA)
        XCTAssertEqual(d.imdbRating?.value, 7.4)
        XCTAssertEqual(d.imdbRating?.link, "https://www.imdb.com/title/tt1600194/")
        XCTAssertEqual(d.kpRating?.value, 7.69)
        XCTAssertEqual(d.kpRating?.votesCount, "9,7K")
        XCTAssertEqual(d.kpRating?.link, "https://www.kinopoisk.ru/film/503148/")
        XCTAssertEqual(d.releaseDate, "20 сентября 2010 года")
        XCTAssertEqual(d.ageRestriction, "16+")
        XCTAssertEqual(d.duration, "42 мин.")
        XCTAssertEqual(d.producer?.count, 4)
        XCTAssertEqual(d.lists?.first?.moviePosition, 12)
        XCTAssertEqual(d.collections, ["https://hdrezka.ag/741-serialy-cbs": "Сериалы CBS",
                                       "https://hdrezka.ag/164-serialy-pro-policeyskih": "Сериалы про полицейских"])
        XCTAssertEqual(d.actors?.first?.name, "Алекс О’Локлин")
        XCTAssertNil(d.singleVoiceActingName)
        XCTAssertEqual(d.seasons?.count, 10)
        XCTAssertEqual(d.voiceActing?.count, 6)
        XCTAssertEqual(d.schedule?.count, 10)
        XCTAssertEqual(d.voiceActingRating?.count, 6, "one popularity row per voice acting (1.6.0 joined them into one)")
        XCTAssertNil(d.franchise)
        XCTAssertEqual(d.commentsCount, 272)
    }

    func testRestrictedSeriesSkipsSeasons() throws {
        let d = try XCTUnwrap(MovieDetailsParser().parseMovieDetails(html: series, movieId: "1605").first)
        XCTAssertEqual(d.availability, .UNAVAILABLE)
        XCTAssertNil(d.seasons)
        XCTAssertNil(d.voiceActing)
        XCTAssertEqual(d.schedule?.count, 10)
    }

    // MARK: Unusual pages (a fixture with one block removed): a throw ends in the details Retry state, the rest falls back

    private func parsed(_ html: String, movieId: String = "205") throws -> MovieDetailed {
        try XCTUnwrap(MovieDetailsParser().parseMovieDetails(html: html, movieId: movieId).first)
    }

    func testPageWithoutMovieBlockOrTitleThrows() throws {
        let noMain = try film.replacingOccurrences(of: #"class="b-content__main""#, with: #"class="gone""#)
        let noTitle = try series.replacingOccurrences(of: #"class="b-post__title""#, with: #"class="gone""#)
        let parser = MovieDetailsParser()
        XCTAssertThrowsError(try parser.parseMovieDetails(html: noMain, movieId: "205"))
        XCTAssertThrowsError(try parser.parseMovieDetails(html: noTitle, movieId: "1605"))
        XCTAssertTrue(parser.movieDetailed.isEmpty, "a failed parse appends nothing")
    }

    func testPlayablePageWithoutVoiceActingThrows() throws {
        // No translator list and no initCDN*Events call: nothing to play, and the play/download sheets index into voiceActing.
        let noActing = try film.replacingOccurrences(of: #"id="translators-list""#, with: #"id="no-list""#)
            .replacingOccurrences(of: "initCDNMoviesEvents", with: "initCDNOtherEvents")
        let playable = noActing.replacingOccurrences(of: "b-player__restricted", with: "b-player__open")
        XCTAssertThrowsError(try MovieDetailsParser().parseMovieDetails(html: playable, movieId: "205"))
        XCTAssertNil(try parsed(noActing).voiceActing, "a restricted page never reads voice actings")
    }

    func testPageWithoutGenresHasNone() throws {
        let d = try parsed(film.replacingOccurrences(of: "<h2>Жанр</h2>", with: "<h2>Жанры</h2>"))
        XCTAssertTrue(d.genres.isEmpty)
        XCTAssertEqual(d.country, "США")
    }

    func testPageWithoutSidecoverOrDescriptionFallsBackToEmpty() throws {
        let noCover = try parsed(film.replacingOccurrences(of: #"class="b-sidecover""#, with: #"class="gone""#))
        XCTAssertEqual(noCover.poster, "")
        XCTAssertEqual(noCover.hPoster, "")
        XCTAssertEqual(noCover.nameRussian, "Голодные игры")
        let noText = try parsed(series.replacingOccurrences(of: #"class="b-post__description""#, with: #"class="gone""#), movieId: "1605")
        XCTAssertEqual(noText.description, "")
        XCTAssertEqual(noText.duration, "42 мин.")
    }

    func testRatingLinkWithoutHelpWrapperIsKept() throws {
        let html = try film.replacingOccurrences(of: "/help/aHR0cHMlM0ElMkYlMkZ3d3cuaW1kYi5jb20lMkZ0aXRsZSUyRnR0MTM5MjE3MCUyRg==/",
                                                 with: "https://www.imdb.com/title/tt1392170/")
        let d = try parsed(html)
        XCTAssertEqual(d.imdbRating?.value, 7.2)
        XCTAssertEqual(d.imdbRating?.link, "https://www.imdb.com/title/tt1392170/")
        XCTAssertEqual(d.kpRating?.link, "https://www.kinopoisk.ru/film/468581/")
    }

    func testMovieListEntryWithoutPositionOrLink() throws {
        // The position is never shown, so an entry without "(N место)" keeps its link with position 0;
        // an entry without a link has nothing to open and is dropped.
        let noPosition = try parsed(film.replacingOccurrences(of: " (19 место)", with: ""))
        XCTAssertEqual(noPosition.lists?.count, 6)
        XCTAssertEqual(noPosition.lists?.first?.name, "Лучшие боевики 2012 года")
        XCTAssertEqual(noPosition.lists?.first?.moviePosition, 0)
        XCTAssertEqual(try parsed(film.replacingOccurrences(of: "(19 место)", with: "(новинка)")).lists?.first?.moviePosition, 0)
        let noLink = try parsed(film.replacingOccurrences(of: #"<a href="https://hdrezka.ag/films/best/action/2012/">Лучшие боевики 2012 года</a>"#,
                                                          with: "Лучшие боевики 2012 года"))
        XCTAssertEqual(noLink.lists?.count, 5)
        XCTAssertEqual(noLink.lists?.last?.moviePosition, 140)
    }

    func testInfoRowsWithoutTheirMarkupFallBack() throws {
        let noAgeSpan = try parsed(film.replacingOccurrences(of: #"<span class="bold" style="color: #666;">12+</span>"#, with: "12+"))
        XCTAssertEqual(noAgeSpan.ageRestriction, "0+", "the default of a page without the row")
        let noHolder = try parsed(film.replacingOccurrences(of: #"<h2>Режиссер</h2>:</td> <td> <div class="persons-list-holder">"#,
                                                            with: #"<h2>Режиссер</h2>:</td> <td> <div class="gone">"#))
        XCTAssertNil(noHolder.producer)
        XCTAssertEqual(noHolder.actors?.first?.name, "Дженнифер Лоуренс")
        // the "Дата выхода" row without its value cell
        let oneCell = try parsed(film.replacingOccurrences(of: #"<td>12 марта <a href="https://hdrezka.ag/year/2012/">2012 года</a></td>"#, with: ""))
        XCTAssertNil(oneCell.releaseDate)
        XCTAssertEqual(oneCell.country, "США")
        let noTable = try parsed(film.replacingOccurrences(of: #"class="b-post__info""#, with: #"class="gone""#))
        XCTAssertEqual(noTable.duration, "nil")
        XCTAssertEqual(noTable.ageRestriction, "0+")
        XCTAssertTrue(noTable.genres.isEmpty)
        XCTAssertNil(noTable.imdbRating)
        XCTAssertNil(noTable.actors)
    }

    func testSeasonWithoutEpisodeListFallsBack() throws {
        // A tab whose episode list is missing keeps its season with no episodes (the sheets handle an empty list).
        let html = try series.replacingOccurrences(of: "b-player__restricted", with: "b-player__open")
            .replacingOccurrences(of: #"id="simple-episodes-list-3""#, with: #"id="gone""#)
        let seasons = try XCTUnwrap(parsed(html, movieId: "1605").seasons)
        XCTAssertEqual(seasons.map { $0.episodes.count }, [24, 23, 0, 22, 25, 25, 25, 25, 25, 22])
        // No season tabs and no episodes: no seasons. An episode naming a season without a list: that season is empty.
        let noEpisodes = try series.replacingOccurrences(of: #"id="simple-seasons-tabs""#, with: #"id="no-tabs""#)
            .replacingOccurrences(of: "b-simple_episode__item", with: "gone")
        XCTAssertNil(try SwiftSoup.parse(noEpisodes).getSeasons())
        let mismatch = #"<div id="simple-episodes-tabs"><ul id="simple-episodes-list-1"><li class="b-simple_episode__item" data-season_id="2" data-episode_id="1">Серия 1</li></ul></div>"#
        XCTAssertEqual(try SwiftSoup.parse(mismatch).getSeasons()?.map { $0.episodes.count }, [0])
    }

    // MARK: Document extensions

    func testSeasonsAndEpisodes() throws {
        let seasons = try XCTUnwrap(SwiftSoup.parse(series).getSeasons())
        XCTAssertEqual(seasons.map(\.id), (1...10).map(String.init))
        XCTAssertEqual(seasons.map { $0.episodes.count }, [24, 23, 24, 22, 25, 25, 25, 25, 25, 22])
        let first = seasons[0]
        XCTAssertEqual(first.name, "Сезон 1")
        XCTAssertTrue(first.isSelected)
        XCTAssertNil(first.url)
        XCTAssertEqual(first.episodes[0], MovieEpisode(id: "1", name: "Серия 1", isSelected: true, url: nil))
        XCTAssertEqual(first.episodes[1], MovieEpisode(id: "2", name: "Серия 2", isSelected: false, url: nil))
        XCTAssertFalse(seasons[1].isSelected)
        XCTAssertNil(try SwiftSoup.parse(film).getSeasons())
    }

    func testSingleSeasonPageWithoutTabs() throws {
        // No ul#simple-seasons-tabs: the id comes from the first episode, the name is "Сезон <id>" (no-op regex).
        let html = """
        <div id="simple-episodes-tabs"><ul id="simple-episodes-list-1" class="b-simple_episodes__list clearfix">
        <li class="b-simple_episode__item active" data-id="7" data-season_id="1" data-episode_id="1">Серия 1</li>
        <li class="b-simple_episode__item" data-id="7" data-season_id="1" data-episode_id="2" href="/series/x/7-1-1-2.html">Серия 2</li>
        </ul></div>
        """
        XCTAssertEqual(try SwiftSoup.parse(html).getSeasons(), [
            MovieSeason(id: "1", name: "Сезон 1", episodes: [MovieEpisode(id: "1", name: "Серия 1", isSelected: true, url: nil),
                                                           MovieEpisode(id: "2", name: "Серия 2", isSelected: false,
                                                                        url: "/series/x/7-1-1-2.html")],
                        isSelected: true, url: nil),
        ])
    }

    /// Markup none of the fixtures carry (premium voice actings, items with their own page link), built from the binary's selectors.
    func testPremiumVoiceActingAndItemLinks() throws {
        let list = #"<ul id="translators-list"><li class="b-translator__item b-prem_translator" data-translator_id="111" href="/films/x/1-111.html">Premium</li></ul>"#
        XCTAssertEqual(try SwiftSoup.parse(list).getVoiceActing(movieId: "1"), [
            MovieVoiceActing(id: "1", name: "Premium", translatorId: "111", isCamrip: "", isAds: "", isDirector: "",
                             isSelected: false, isPremium: true, url: "/films/x/1-111.html"),
        ])
        let tabs = """
        <ul id="simple-seasons-tabs"><li class="b-simple_season__item active" data-tab_id="2" href="/series/x/7-1-2.html">Сезон 2</li></ul>
        <div id="simple-episodes-tabs"><ul id="simple-episodes-list-2">
        <li class="b-simple_episode__item" data-season_id="2" data-episode_id="5" href="/series/x/7-1-2-5.html">Серия 5</li>
        </ul></div>
        """
        XCTAssertEqual(try SwiftSoup.parse(tabs).getSeasons(), [
            MovieSeason(id: "2", name: "Сезон 2", episodes: [MovieEpisode(id: "5", name: "Серия 5", isSelected: false,
                                                                         url: "/series/x/7-1-2-5.html")],
                        isSelected: true, url: "/series/x/7-1-2.html"),
        ])
    }

    func testVoiceActingList() throws {
        let actings = try SwiftSoup.parse(series).getVoiceActing(movieId: "1605")
        XCTAssertEqual(actings.map(\.translatorId), ["1", "232", "359", "389", "392", "420"])
        XCTAssertEqual(actings[0], MovieVoiceActing(id: "1605", name: "лостфильм (LostFilm)", translatorId: "1", isCamrip: "",
                                                    isAds: "", isDirector: "", isSelected: true, isPremium: false, url: nil))
        XCTAssertEqual(actings[2].name, "Украинский многоголосый\u{00A0}🇺🇦")
        XCTAssertFalse(actings[1].isSelected)
    }

    func testFilmVoiceActingList() throws {
        let actings = try SwiftSoup.parse(film).getVoiceActing(movieId: "205")
        XCTAssertEqual(actings.map(\.translatorId), ["56", "58", "358", "389", "581", "432", "238"])
        XCTAssertEqual(actings[0], MovieVoiceActing(id: "205", name: "Дубляж", translatorId: "56", isCamrip: "0", isAds: "0",
                                                    isDirector: "0", isSelected: true, isPremium: false, url: nil))
        XCTAssertEqual(actings[2].name, "Украинский дубляж\u{00A0}🇺🇦")
    }

    func testVoiceActingFromPlayerArgumentsWhenNoList() throws {
        let html = try film.replacingOccurrences(of: "id=\"translators-list\"", with: "id=\"no-list\"")
        let actings = try SwiftSoup.parse(html).getVoiceActing(movieId: "205")
        XCTAssertEqual(actings, [MovieVoiceActing(id: "205", name: "", translatorId: "56", isCamrip: "", isAds: "",
                                                  isDirector: "", isSelected: true, isPremium: false, url: nil)])
        let series = try series.replacingOccurrences(of: "id=\"translators-list\"", with: "id=\"no-list\"")
        XCTAssertEqual(try SwiftSoup.parse(series).getVoiceActing(movieId: "1605").map(\.translatorId), ["1"])
    }

    func testSchedule() throws {
        let schedule = try XCTUnwrap(SwiftSoup.parse(series).getSchedule())
        XCTAssertEqual(schedule.count, 10)
        XCTAssertEqual(schedule[0].name, "Гавайи 5.0 / Полиция Гавайев - даты выхода серий 10 сезона")
        XCTAssertEqual(schedule[0].items.count, 23)
        let item = schedule[0].items[0]
        XCTAssertEqual(item.title, "10 сезон 22 серия")
        XCTAssertEqual(item.russianEpisodeName, "Серия 22")
        XCTAssertEqual(item.originalEpisodeName, "Aloha")
        XCTAssertEqual(item.releaseDate, "4 апреля 2020")
        // the "загрузить еще серии" row is kept as an empty item, as in the original
        XCTAssertEqual(schedule[0].items.last?.title, "")
        XCTAssertNil(schedule[0].items.last?.originalEpisodeName)
        XCTAssertEqual(schedule[9].name, "1 сезон")
        XCTAssertNil(try SwiftSoup.parse(film).getSchedule())
    }

    func testFranchise() throws {
        let parts = try XCTUnwrap(SwiftSoup.parse(film).getFranchise())
        XCTAssertEqual(parts.count, 5)
        XCTAssertEqual(parts[0], MovieFranchisePart(id: "https://hdrezka.ag/films/fiction/57108-golodnye-igry-ballada-o-zmeyah-i-pevchih-pticah-2023.html",
                                                    name: "Голодные игры: Баллада о змеях и певчих птицах", year: "2023 год",
                                                    rating: 7.16, current: false, position: 5))
        XCTAssertEqual(parts[4], MovieFranchisePart(id: "", name: "Голодные игры", year: "2012 год", rating: 7.27, current: true, position: 1))
        XCTAssertNil(try SwiftSoup.parse(series).getFranchise())
    }

    func testVoiceActingRatingHasOneEntryPerRow() throws {
        // improvement: one entry per row of the popularity tooltip; the original mapped the whole div.inner list at
        // once, so every row ended up in a single entry with percent 0. The page's voice acting rows show these shares.
        let ratings = try XCTUnwrap(SwiftSoup.parse(series).getVoiceActingRating())
        XCTAssertEqual(ratings.map(\.name), ["лостфильм (LostFilm)", "Украинский (ТРК Украина)\u{00A0}🇺🇦", "Украинский многоголосый\u{00A0}🇺🇦",
                                             "Украинский (1+1)\u{00A0}🇺🇦", "Украинский (НТН)\u{00A0}🇺🇦", "TVShows"])
        XCTAssertEqual(ratings[0].percent, 98.49, accuracy: 0.001)
        XCTAssertEqual(ratings[2].percent, 0.4, accuracy: 0.001)
        XCTAssertEqual(ratings[5].percent, 0.08, accuracy: 0.001)
        XCTAssertNil(try SwiftSoup.parse(film).getVoiceActingRating())

        let single = #"<span class="b-rgstats__help" title="&lt;div class=&quot;inner&quot;&gt;&lt;div class=&quot;title&quot;&gt;Дубляж&lt;/div&gt;&lt;div class=&quot;count&quot;&gt;98,49%&lt;/div&gt;&lt;/div&gt;">?</span>"#
        let one = try XCTUnwrap(SwiftSoup.parse(single).getVoiceActingRating())
        XCTAssertEqual(one.map(\.name), ["Дубляж"])
        XCTAssertEqual(one.first?.percent ?? 0, 98.49, accuracy: 0.001)
    }

    func testCommentsCount() throws {
        XCTAssertEqual(try SwiftSoup.parse(film).getCommentsCount(), 539)
        XCTAssertEqual(try SwiftSoup.parse("<p>no comments</p>").getCommentsCount(), 0)
    }

    func testAvailability() throws {
        XCTAssertFalse(try SwiftSoup.parse(film).isAvailable())
        XCTAssertFalse(try SwiftSoup.parse(film).isComingSoon())
        XCTAssertTrue(try SwiftSoup.parse("<div class=\"b-post__status_logo\"></div>").isComingSoon())
        XCTAssertTrue(try SwiftSoup.parse("<div></div>").isAvailable())
    }

    /// Account-only markup: built from the selectors of the binary, not captured (needs a session).
    func testBookmarks() throws {
        let html = """
        <div id="user-favorites-list">
          <div class="hd-label-row"><input type="checkbox" value="101" checked><label>Избранное (3)</label></div>
          <div class="hd-label-row"><input type="checkbox" value="102"><label>Позже (0)</label></div>
        </div>
        """
        let bookmarks = try SwiftSoup.parse(html).getBookmarks()
        XCTAssertEqual(bookmarks, [Bookmark(id: 101, name: "Избранное "): true, Bookmark(id: 102, name: "Позже "): false])
    }

    func testCheckPremiumStoresBadgeText() throws {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: "hasPremium")
        defer { defaults.set(saved, forKey: "hasPremium") }

        let doc = try SwiftSoup.parse(#"<div class="b-tophead-premuser"><a href="/payments/">Premium <b>осталось 12 дней</b></a></div>"#)
        XCTAssertTrue(try doc.checkPremium() === doc)
        XCTAssertEqual(defaults.string(forKey: "hasPremium"), "осталось 12 дней")
        // A guest's page of the site: its header menu, no badge (a page without the menu says nothing about it).
        _ = try SwiftSoup.parse(#"<div id="topnav-menu"></div><p>guest</p>"#).checkPremium()
        XCTAssertEqual(defaults.string(forKey: "hasPremium"), "")
    }

    // MARK: Element / [Element] extensions

    func testInfoTableChunks() throws {
        let main = try XCTUnwrap(SwiftSoup.parse(film).select("div.b-content__main").first())
        var labels: [String] = []
        main.getDetailsChunked { chunk in labels.append((try? chunk[0].getElementsByTag("h2").text()) ?? "?") }
        XCTAssertEqual(labels, ["Рейтинги", "Входит в списки", "Слоган", "Дата выхода", "Страна", "Режиссер", "Жанр",
                                "В качестве", "В переводе", "Возраст", "Время", "Из серии", "В ролях актеры"])
    }

    func testKpRatingFallsBackToZero() throws {
        // Unlike getImdbRating (nil), the binary parses `?? "0"` when the kp span or its .bold is missing.
        func chunk(_ value: String) throws -> [SwiftSoup.Element] {
            try SwiftSoup.parse("<table><tr><td><h2>Рейтинги</h2>:</td><td>\(value)</td></tr></table>").select("td").array()
        }
        XCTAssertEqual(try chunk(#"<span class="b-post__info_rates kp"><a href="/help/x/">Кинопоиск</a>: <i>(9 715)</i></span>"#).getKpRating(), 0)
        XCTAssertEqual(try chunk("").getKpRating(), 0)
        XCTAssertNil(try chunk("").getImdbRating())
        XCTAssertNil(try chunk(#"<span class="b-post__info_rates imdb"><a href="/help/x/">IMDb</a>: <i>(9 715)</i></span>"#).getImdbRating())

        // Votes and link are still there, so the page keeps a KP rating of 0.
        let html = try film.replacingOccurrences(of: #"<span class="bold">7.27</span>"#, with: "")
        let d = try XCTUnwrap(MovieDetailsParser().parseMovieDetails(html: html, movieId: "205").first)
        XCTAssertEqual(d.kpRating?.value, 0)
        XCTAssertEqual(d.kpRating?.votesCount, "503K")
        XCTAssertEqual(d.kpRating?.link, "https://www.kinopoisk.ru/film/468581/")
        XCTAssertEqual(d.imdbRating?.value, 7.2)
    }

    // MARK: parseSeriesSeasons / parseTrailerId

    func testParseSeriesSeasonsFromPage() throws {
        let parser = MovieDetailsParser()
        let seasons = try XCTUnwrap(parser.parseSeriesSeasons(series))
        XCTAssertEqual(seasons.count, 10)
        XCTAssertEqual(seasons[0].name, "Сезон 1")
        XCTAssertTrue(parser.movieSeason.isEmpty, "the page path returns getSeasons() as is")
    }

    func testParseSeriesSeasonsFromEpisodesJSON() throws {
        let json = """
        {"success":true,"message":"","seasons":"<li class=\\"b-simple_season__item active\\" data-tab_id=\\"1\\">Сезон 1</li><li class=\\"b-simple_season__item\\" data-tab_id=\\"2\\">Сезон 2</li>","episodes":"<ul id=\\"simple-episodes-list-1\\" class=\\"b-simple_episodes__list clearfix\\"><li class=\\"b-simple_episode__item active\\" data-id=\\"1605\\" data-season_id=\\"1\\" data-episode_id=\\"1\\">Серия 1</li><li class=\\"b-simple_episode__item\\" data-id=\\"1605\\" data-season_id=\\"1\\" data-episode_id=\\"2\\">Серия 2</li></ul><ul id=\\"simple-episodes-list-2\\" class=\\"b-simple_episodes__list clearfix\\"><li class=\\"b-simple_episode__item\\" data-id=\\"1605\\" data-season_id=\\"2\\" data-episode_id=\\"1\\">Серия 1</li></ul>"}
        """
        let parser = MovieDetailsParser()
        let seasons = try XCTUnwrap(parser.parseSeriesSeasons(json))
        // here the binary applies the regex for real: only digits and ASCII punctuation survive
        XCTAssertEqual(seasons, [
            MovieSeason(id: "1", name: "1", episodes: [MovieEpisode(id: "1", name: "1", isSelected: true, url: nil),
                                                       MovieEpisode(id: "2", name: "2", isSelected: false, url: nil)],
                        isSelected: true, url: nil),
            MovieSeason(id: "2", name: "2", episodes: [MovieEpisode(id: "1", name: "1", isSelected: false, url: nil)],
                        isSelected: false, url: nil),
        ])
        XCTAssertEqual(parser.movieSeason, seasons)
        XCTAssertNil(parser.parseSeriesSeasons(#"{"success":false,"message":"oops"}"#))
        XCTAssertNil(parser.parseSeriesSeasons("not json"))
    }

    func testParseTrailerId() throws {
        let response = #"{"success":true,"message":"","code":"<iframe width=\"640\" height=\"360\" src=\"https://www.youtube.com/embed/4S9a5V9ODuY?iv_load_policy=3&modestbranding=1&autoplay=1\" frameborder=\"0\" allowfullscreen></iframe>"}"#
        let parser = MovieDetailsParser()
        XCTAssertEqual(try parser.parseTrailerId(response: response), "4S9a5V9ODuY")
        XCTAssertNil(try parser.parseTrailerId(response: #"{"success":false,"message":"no trailer"}"#))
        XCTAssertNil(try parser.parseTrailerId(response: #"{"success":true,"code":"<p>none</p>"}"#))
        XCTAssertThrowsError(try parser.parseTrailerId(response: "<html>"))
    }
}
