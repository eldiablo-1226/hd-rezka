import XCTest
@testable import HDrezka

/// improvement (critique follow-up): one-tap playback, the cast row, the poster cache and continue-watching dates.
final class CatalogSliceTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)"), encoding: .utf8)
    }

    /// The fixtures are region-restricted pages, which skip voice actings; opened as MovieDetailsParserTests does.
    private func detail(_ fixtureName: String, id: String) throws -> MovieDetailed {
        let html = try fixture(fixtureName).replacingOccurrences(of: "b-player__restricted", with: "b-player__open")
        return try XCTUnwrap(MovieDetailsParser().parseMovieDetails(html: html, movieId: id).first)
    }

    // MARK: what «Смотреть» plays

    func testFilmPlaysThePagesVoiceActing() throws {
        let film = try detail("details-film-hunger-games.html", id: "205")
        let choice = try XCTUnwrap(PlaybackChoice.default(for: film))
        let marked = try XCTUnwrap(film.voiceActing?.first(where: \.isSelected) ?? film.voiceActing?.first)
        XCTAssertEqual(choice.acting, marked)
        XCTAssertNil(choice.season)
        XCTAssertNil(choice.episode)
        XCTAssertEqual(choice.caption, marked.name)
    }

    func testSeriesPlaysTheMarkedEpisode() throws {
        let series = try detail("details-series-hawaii.html", id: "1605")
        let choice = try XCTUnwrap(PlaybackChoice.default(for: series))
        let seasons = try XCTUnwrap(series.seasons)
        let season = seasons.first(where: \.isSelected) ?? seasons[0]
        XCTAssertEqual(choice.season, season)
        XCTAssertEqual(choice.episode, season.episodes.first(where: \.isSelected) ?? season.episodes.first)
        XCTAssertEqual(choice.caption, "\(season.name), \(choice.episode!.name) · \(choice.acting.name)")
    }

    /// Without a subscription a marked premium voice acting would only explain that it can't play.
    func testLockedVoiceActingFallsBackToAFreeOne() {
        let premium = acting("1", selected: true, premium: true), free = acting("2", selected: false, premium: false)
        XCTAssertEqual(PlaybackChoice.default(voiceActing: [premium, free], seasons: nil, hasPremium: false)?.acting, free)
        XCTAssertEqual(PlaybackChoice.default(voiceActing: [premium, free], seasons: nil, hasPremium: true)?.acting, premium)
        XCTAssertEqual(PlaybackChoice.default(voiceActing: [premium], seasons: nil, hasPremium: false)?.acting, premium,
                       "nothing free: the sheet then says why")
    }

    /// A page without a translator list gives a nameless voice acting; the caption leaves out empty parts.
    func testCaptionSkipsEmptyParts() {
        XCTAssertEqual(PlaybackChoice(acting: acting("1", name: ""), season: nil, episode: nil).caption, "")
        let season = MovieSeason(id: "1", name: "Сезон 1", episodes: [], isSelected: true, url: nil)
        let episode = MovieEpisode(id: "2", name: "Серия 2", isSelected: true, url: nil)
        XCTAssertEqual(PlaybackChoice(acting: acting("1", name: ""), season: season, episode: episode).caption, "Сезон 1, Серия 2")
    }

    private func acting(_ translator: String, name: String? = nil, selected: Bool = false, premium: Bool = false) -> MovieVoiceActing {
        // The parser gives every voice acting of a page the page's id (MovieDetailsParser getVoiceActing).
        MovieVoiceActing(id: "205", name: name ?? "Studio \(translator)", translatorId: translator, isCamrip: "", isAds: "",
                         isDirector: "", isSelected: selected, isPremium: premium, url: nil)
    }

    func testNoVoiceActingMeansTheFullSheet() {
        XCTAssertNil(PlaybackChoice.default(voiceActing: [], seasons: nil))
        XCTAssertNil(PlaybackChoice.default(voiceActing: nil, seasons: nil))
        let acting = MovieVoiceActing(id: "1", name: "Studio", translatorId: "1", isCamrip: "", isAds: "", isDirector: "",
                                      isSelected: false, isPremium: false, url: nil)
        let empty = MovieSeason(id: "1", name: "Сезон 1", episodes: [], isSelected: true, url: nil)
        XCTAssertNil(PlaybackChoice.default(voiceActing: [acting], seasons: [empty]), "a season without episodes")
    }

    // MARK: cast photos

    func testCastCarriesPhotos() throws {
        let film = try detail("details-film-hunger-games.html", id: "205")
        let director = try XCTUnwrap(film.producer?.first)
        XCTAssertEqual(director.photo, "https://static.hdrezka.ac/i/2016/3/10/ff248bc70196ezu94x34a.jpg")
        XCTAssertFalse(film.actors?.isEmpty ?? true)
        XCTAssertTrue(film.actors?.allSatisfy { $0.photo == nil || $0.photo!.hasPrefix("http") } ?? false,
                      "the site writes data-photo=\"null\" for people without a photo")
    }

    // MARK: posters of continue-watching items

    @MainActor
    func testPosterCacheKeepsTheLatestEntries() {
        let defaults = UserDefaults(suiteName: "PosterCacheTests")!
        defaults.removePersistentDomain(forName: "PosterCacheTests")
        let cache = PosterCache(defaults: defaults, limit: 2)
        cache.store("https://img/1.jpg", for: "https://ijobs.app/films/1.html")
        cache.store("https://img/2.jpg", for: "https://ijobs.app/films/2.html")
        cache.store("https://img/3.jpg", for: "https://ijobs.app/films/3.html")
        XCTAssertNil(cache.poster(for: "https://ijobs.app/films/1.html"), "the oldest entry goes first")
        XCTAssertEqual(cache.poster(for: "https://ijobs.app/films/3.html"), "https://img/3.jpg")
        XCTAssertEqual(cache.poster(for: "https://hdrezka.me/films/2.html"), "https://img/2.jpg", "keyed by path, not mirror")
    }

    // MARK: continue-watching dates

    func testSiteDatesAreShownAsDates() {
        let shown = WatchLaterCardComponent.displayDate("04-11-2026", locale: Locale(identifier: "ru_RU"))
        XCTAssertFalse(shown.contains("-"))
        XCTAssertTrue(shown.contains("2026"))
        XCTAssertEqual(WatchLaterCardComponent.displayDate("сегодня", locale: Locale(identifier: "ru_RU")), "сегодня")
        XCTAssertEqual(WatchLaterCardComponent.displayDate("вчера", locale: Locale(identifier: "ru_RU")), "вчера")
    }

    // MARK: Home refresh keeps the list

    @MainActor
    func testFailedRefreshKeepsTheList() throws {
        let network = Network()
        network.finishMoviesRequest(html: try fixture("catalog-listing.html"))
        let listed = network.movies.count
        XCTAssertGreaterThan(listed, 0)
        network.beginRefresh()
        network.finishMoviesRequest(html: nil)
        XCTAssertEqual(network.movies.count, listed)
        XCTAssertTrue(network.moviesRefreshFailed)
        XCTAssertFalse(network.moviesLoadFailed, "the list is still on screen")
    }

    @MainActor
    func testRefreshReplacesTheList() throws {
        let network = Network()
        let page = try fixture("catalog-listing.html")
        network.finishMoviesRequest(html: page)
        let listed = network.movies.count
        network.movies.insert(.placeholder, at: 0)  // a film the fresh page no longer lists
        network.beginRefresh()
        network.finishMoviesRequest(html: page, page: 1)
        XCTAssertEqual(network.movies.count, listed, "replaced, not appended")
        XCTAssertFalse(network.movies.contains(.placeholder))
        XCTAssertFalse(network.moviesRefreshFailed)
    }

    /// A page requested before the refresh arrives after it: dropped, so it can't land above page 1.
    @MainActor
    func testAnswerFromBeforeARefreshIsDropped() async throws {
        let network = Network()
        let old = network.moviesGeneration
        network.beginRefresh()
        network.receivePage(try fixture("catalog-listing.html"), generation: old, page: 3)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(network.movies.isEmpty)
        // Control: the same page for the current generation does land.
        network.receivePage(try fixture("catalog-listing.html"), generation: network.moviesGeneration, page: 1)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(network.movies.isEmpty)
    }

    /// The same film on two overlapping pages is listed once.
    @MainActor
    func testListingSkipsDuplicates() throws {
        let network = Network()
        let page = try fixture("catalog-listing.html")
        network.finishMoviesRequest(html: page)
        let listed = network.movies.count
        network.finishMoviesRequest(html: page)
        XCTAssertEqual(network.movies.count, listed)
    }
}
