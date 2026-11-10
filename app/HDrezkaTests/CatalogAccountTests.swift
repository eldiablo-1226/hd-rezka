import XCTest
import Combine
@testable import HDrezka

/// Listings, search, collections, people, account and the version header (area a2).
/// Public pages are live captures from ijobs.app (2026-11-10); `catalog-account-*` fixtures are
/// synthetic because those pages need a session.
final class CatalogAccountTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)"), encoding: .utf8)
    }

    // MARK: - Listings and search

    @MainActor
    func testMoviesURLUsesStartPageOnlyForFirstPageOfLast() {
        let network = Network()
        let host = "https://\(network.settingStore)"
        XCTAssertEqual(network.moviesURL(page: 1, filter: "last"), "\(host)/?filter=last")
        XCTAssertEqual(network.moviesURL(page: 2, filter: "last"), "\(host)/page/2/?filter=last")
        XCTAssertEqual(network.moviesURL(page: 1, filter: "popular"), "\(host)/page/1/?filter=popular")
    }

    @MainActor
    func testListingPageAppendsToMovies() throws {
        let network = Network()
        let html = try fixture("catalog-listing.html")
        let movies = try network.parse(html: html)
        XCTAssertEqual(movies.count, 36)
        XCTAssertEqual(movies.first, MovieSimple(
            id: "https://ijobs.app/films/drama/93758-otmschenie-moe-1984.html",
            name: "Отмщение моё",
            details: "1984, США, Драмы",
            poster: "https://static.hdrezka.ac/i/2026/11/9/rc5f861c18d82hd25c99o.jpg"))
        XCTAssertEqual(movies.last?.id, "https://ijobs.app/films/documentary/93721-kriki-i-shepot-1988.html")
        XCTAssertEqual(network.movies, movies)
        XCTAssertEqual(try network.parse(html: html).count, 72, "parsing appends, the caller clears")
        XCTAssertTrue(network.search.isEmpty)
    }

    /// fetchMovies hands the arrived page to receivePage. SwiftUI (and Nuke 12.9's LazyImage) must see every change on main.
    @MainActor
    func testArrivedListingPageIsPublishedOnMainThread() throws {
        let network = Network()
        let published = expectation(description: "the whole page is published")
        var onMain: [Bool] = []
        let subscription = network.$movies.dropFirst().sink { movies in
            onMain.append(Thread.isMainThread)
            if movies.count == 36 { published.fulfill() }
        }
        network.receivePage(try fixture("catalog-listing.html"))
        wait(for: [published], timeout: 5)
        subscription.cancel()
        XCTAssertEqual(onMain, Array(repeating: true, count: 36))
    }

    @MainActor
    func testSearchAndBookmarkPagesUseTheirOwnLists() throws {
        let network = Network()
        let search = try network.parseSearch(html: fixture("catalog-search.html"))
        XCTAssertEqual(search.count, 9)
        XCTAssertEqual(search.first?.name, "Матрица")
        XCTAssertEqual(search.first?.details, "1999, США, Фантастика")
        XCTAssertEqual(network.search, search)

        let bookmarks = try network.parseBookmarks(html: fixture("catalog-listing.html"))
        XCTAssertEqual(bookmarks.count, 36)
        XCTAssertEqual(network.bookmarks, bookmarks)
        XCTAssertTrue(network.movies.isEmpty)
    }

    @MainActor
    func testQuickSearch() throws {
        let network = Network()
        let results = try network.parseQuickSearch(html: fixture("catalog-quick-search.html"))
        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(results.first?.id, "https://ijobs.app/films/fiction/981-matrica-1999-latest.html")
        XCTAssertEqual(results.first?.name, "Матрица")
        XCTAssertEqual(results.first?.details, " (The Matrix, 1999)")
        XCTAssertEqual(results.last?.name, "Армитаж: Полиматрица")
        XCTAssertEqual(network.quickSearch.count, 5)
    }

    // MARK: - Collections

    func testCollections() throws {
        let parser = CollectionsParser()
        let collections = try parser.parseCollections(fixture("catalog-collections.html"))
        XCTAssertEqual(collections.count, 36)
        XCTAssertEqual(collections.first, HDrezka.Collection(
            id: "4768-filmy-xyz-films",
            name: "Фильмы XYZ Films",
            poster: "https://static.hdrezka.ac/i/2026/11/8/w90b417f7ed19xh81x99m.jpg",
            count: 60))
        XCTAssertEqual(collections.last?.id, "2527-serial-po-komiksam-dark-horse-comics")
        XCTAssertEqual(collections.last?.count, 4)
        XCTAssertEqual(parser.collections, collections)
    }

    func testMoviesInCollection() throws {
        let parser = CollectionsParser()
        let movies = try parser.parseMoviesInCollection(fixture("catalog-collection.html"))
        XCTAssertEqual(movies.count, 4)
        XCTAssertEqual(movies.first, MovieSimple(
            id: "https://ijobs.app/films/action/28802-noch-idet-za-nami-2018.html",
            name: "Ночь идёт за нами",
            details: "2018, Индонезия, Боевики",
            poster: "https://static.hdrezka.ac/i/2022/11/28/ebc55d7bfe763th56s19t.jpg"))
        XCTAssertEqual(parser.moviesInCollections, movies)
    }

    // MARK: - People

    func testPersonPage() throws {
        let person = try PeopleParser().parse(html: fixture("catalog-person.html"))
        XCTAssertEqual(person.nameRu, "Вуди Харрельсон")
        XCTAssertEqual(person.nameOrig, "Woody Harrelson")
        XCTAssertEqual(person.photo, "https://static.hdrezka.ac/i/2016/3/10/ed2d8059fab33uo27z17l.jpg")
        XCTAssertEqual(person.career, "актер, режиссер, сценарист, продюсер")
        XCTAssertEqual(person.birthDate, "23 июля, 1961 (65 лет)")
        XCTAssertEqual(person.birthPlace, "Мидленд, Техас, США")
        XCTAssertEqual(person.height, "1.77 м")
        XCTAssertNil(person.deathDate)
        XCTAssertNil(person.deathPlace)
        XCTAssertEqual(person.actorMovies?.count, 87, "6 visible cards + 81 `.is_hidden` ones")
        XCTAssertEqual(person.actorMovies?.first, MovieSimple(
            id: "https://ijobs.app/series/detective/1201-nastoyaschiy-detektiv-2014-latest.html",
            name: "Настоящий детектив",
            details: "2014 - ..., США, Детективы",
            poster: "https://static.hdrezka.ac/i/2023/12/5/jf06c6b07d50cns61n71a.jpg"))
        XCTAssertEqual(person.directorMovies?.count, 1)
        XCTAssertEqual(person.screenwriterMovies?.count, 1)
        XCTAssertEqual(person.producerMovies?.count, 3)
        XCTAssertNil(person.operatorMovies)
        XCTAssertNil(person.editorMovies)
        XCTAssertNil(person.artistMovies)
    }

    // MARK: - Account pages (synthetic HTML from the parser selectors)

    @MainActor
    func testSeriesUpdatesKeepOnlyDaysWithTrackedSeries() throws {
        let parser = AccountParser()
        let groups = try parser.parseSeriesUpdates(html: fixture("catalog-account-series-updates.html"))
        XCTAssertEqual(groups.map(\.date), ["Сегодня (10 ноября 2026)", "8 ноября 2026 "])
        XCTAssertEqual(groups.first?.releasedEpisodes.count, 1)
        let item = try XCTUnwrap(groups.first?.releasedEpisodes.first)
        XCTAssertEqual(item.id, "https://ijobs.app/cartoons/adventures/93653-malysh-karlhen-2026.html")
        XCTAssertEqual(item.seriesName, "Малыш Карлхен")
        XCTAssertEqual(item.season, "(1 сезон)")
        XCTAssertEqual(item.releasedEpisode, "15 серия ")
        XCTAssertEqual(item.chosenVoiceActing, "(Дубляж)")
        XCTAssertEqual(groups.last?.releasedEpisodes.map(\.seriesName), ["Гарри Поттер: Волшебники выпечки", "Благодетель"])
        XCTAssertEqual(groups.last?.releasedEpisodes.map(\.chosenVoiceActing), ["Субтитры", "Субтитры"])
        XCTAssertEqual(parser.seriesUpdates.count, 2)
    }

    @MainActor
    func testWatchLaterDropsHeaderRow() throws {
        let parser = AccountParser()
        let movies = try parser.parseWatchingLaterMovies(html: fixture("catalog-account-watch-later.html"))
        XCTAssertEqual(movies, [
            MovieWatchLater(id: "https://ijobs.app/series/drama/80085-blagodetel-2025-latest.html", name: "Благодетель",
                            details: "(Benefactor, 2025)", watchingInfo: "2 сезон 3 серия (Субтитры) ",
                            date: "10 ноября 2026", buttonText: "Смотреть 4 серию", dataId: "111"),
            MovieWatchLater(id: "https://ijobs.app/films/drama/93758-otmschenie-moe-1984.html", name: "Отмщение моё",
                            details: "(Vengeance Is Mine, 1984)", watchingInfo: "Фильм",
                            date: "9 ноября 2026", buttonText: nil, dataId: "222"),
        ])
        XCTAssertEqual(parser.watchingLaterMovies, movies)
    }

    @MainActor
    func testBookmarkCategories() throws {
        let bookmarks = try AccountParser().parseBookmarks(html: fixture("catalog-account-bookmarks.html"))
        XCTAssertEqual(bookmarks, [Bookmark(id: 12, name: "Избранное"), Bookmark(id: 345, name: "Смотреть позже")])
    }

    @MainActor
    func testRegistrationAnswers() throws {
        let parser = AccountParser()
        XCTAssertTrue(try parser.checkRegistration(html: "<script>location.reload();</script>"))
        XCTAssertTrue(try parser.checkRegistration(html: "<script></script>"))
        XCTAssertFalse(try parser.checkRegistration(html: "<script>alert('Ошибка');</script>"))
        XCTAssertFalse(try parser.checkRegistration(html: "<div class=\"error\">Ошибка</div>"))
        XCTAssertTrue(try parser.checkAvailability(html: "<span class=\"string-ok\">Имя свободно</span>"))
        XCTAssertFalse(try parser.checkAvailability(html: "<span class=\"string-error\">Имя занято</span>"))
    }

    // MARK: - Version header

    func testHeaderVersionComesFromAndroidUpdateFeed() throws {
        XCTAssertEqual(try HeaderUpdater.version(fromUpdates: fixture("catalog-updates.json")), "2.2.5")
    }

    // MARK: - Requests (captured by overriding `send`, nothing goes to the network; mirror/version pinned by the spies)

    func testAccountRequests() async throws {
        let network = SpyAccountNetwork()
        let host = "https://\(network.settingStore)"
        let version = network.remoteVersion

        _ = try await network.checkRegistration(["name": "neo"])
        try check(network.sent.last, "POST", "\(host)/engine/ajax/registration.php", version: version,
                  contentType: alamofireFormType, body: "name=neo")
        _ = try await network.getBookmarks()
        try check(network.sent.last, "GET", "\(host)/favorites", version: version)
        _ = try await network.getBookmarksByCategory(id: 7, page: 2)
        try check(network.sent.last, "GET", "\(host)/favorites/7/page/2", version: version, contentType: nil)
        _ = try await network.getLoginResponse(["login_name": "neo"])
        try check(network.sent.last, "POST", "\(host)/ajax/login/", version: version, body: "login_name=neo")
        _ = try await network.getSeriesUpdates()
        try check(network.sent.last, "GET", host, version: version)
        _ = try await network.getSignUpResponse(["data": "a=b"])
        try check(network.sent.last, "POST", "\(host)/engine/ajax/quick_register.php", version: version,
                  contentType: alamofireFormType, body: "data=a%3Db")
        _ = try await network.getWatchingLaterMovies()
        try check(network.sent.last, "GET", "\(host)/continue/", version: version)
        _ = try await network.logout()
        try check(network.sent.last, "GET", "\(host)/logout", version: version)
        _ = try await network.performBookmarksAction(["action": "add_cat"])
        try check(network.sent.last, "POST", "\(host)/ajax/favorites/", version: version, body: "action=add_cat")
        _ = try await network.removeWatchingItem(["id": "5"])
        try check(network.sent.last, "GET", "\(host)/engine/ajax/cdn_saves_remove.php?id=5", version: version)
        _ = try await network.reorderBookmarks(["cats[]": ["3", "1"]])
        try check(network.sent.last, "POST", "\(host)/ajax/favorites/", version: version, body: "cats%5B%5D=3&cats%5B%5D=1")

        _ = try await network.sendWatching(["post_id": "205"])
        let url = try XCTUnwrap(network.sent.last?.url?.absoluteString)
        XCTAssertNotNil(url.range(of: #"^\#(host)/ajax/send_save/\?t=\d{10}&post_id=205$"#, options: .regularExpression), url)
        XCTAssertEqual(network.sent.last?.httpMethod, "GET")
        XCTAssertEqual(network.sent.last?.value(forHTTPHeaderField: "Content-Type"), formType)
        XCTAssertEqual(network.sent.count, 12)
    }

    func testCollectionsAndPeopleRequests() async throws {
        let collections = SpyCollectionsNetwork()
        let host = "https://\(collections.settingStore)"
        _ = try await collections.getCollections(page: 3)
        try check(collections.sent.last, "GET", "\(host)/collections/page/3", version: collections.remoteVersion)
        _ = try await collections.getMoviesInCollectionFiltered(id: "4768-filmy-xyz-films", page: 2, filter: "watching")
        try check(collections.sent.last, "GET", "\(host)/collections/4768-filmy-xyz-films/page/2/?filter=watching",
                  version: collections.remoteVersion)

        let people = SpyPeopleNetwork()
        _ = try await people.getPersonDetails(id: "4176-vudi-harrelson")
        try check(people.sent.last, "GET", "https://\(people.settingStore)/person/4176-vudi-harrelson",
                  version: people.remoteVersion, contentType: nil)
    }

    // MARK: - Form fields built by AccountService

    func testWatchingStateParams() {
        let acting = MovieVoiceActing(id: "https://ijobs.app/films/fiction/205-golodnye-igry-2012.html", name: "Дубляж",
                                      translatorId: "56", isCamrip: "0", isAds: "0", isDirector: "0",
                                      isSelected: true, isPremium: false, url: nil)
        XCTAssertEqual(AccountService.watchingStateParams(voiceActing: acting, season: nil, episode: nil),
                       ["post_id": "205", "translator_id": "56", "season": "0", "episode": "0", "current_time": "1"])
        let season = MovieSeason(id: "2", name: "Сезон 2", episodes: [], isSelected: true, url: nil)
        let episode = MovieEpisode(id: "7", name: "Серия 7", isSelected: true, url: nil)
        let params = AccountService.watchingStateParams(voiceActing: acting, season: season, episode: episode)
        XCTAssertEqual(params["season"], "2")
        XCTAssertEqual(params["episode"], "7")
    }

    func testSignUpDataIsAnUnescapedFormString() {
        let data = AccountService.signUpData(email: "neo@matrix.io", username: "neo", password: "zion")
        XCTAssertEqual(Set(data.components(separatedBy: "&")), [
            "email=neo@matrix.io", "prevent_autofill_name=", "name=neo", "prevent_autofill_password1=",
            "password1=zion", "rules=1", "submit_reg=submit_reg", "do=register",
        ])
    }

    func testReorderParamsKeepCategoryOrder() {
        XCTAssertEqual(AccountService.reorderParams([Bookmark(id: 3, name: "b"), Bookmark(id: 1, name: "a")]),
                       ["action": ["sort_cats"], "cats[]": ["3", "1"]])
    }

    // MARK: - Answers read by AccountService and PeopleRepository (missing keys and non-objects trap, untestable)

    func testLoginReadsTheSuccessFlag() throws {
        XCTAssertTrue(try AccountService.loginSucceeded(#"{"success":true}"#))
        XCTAssertFalse(try AccountService.loginSucceeded(#"{"success":false,"message":"Неверный пароль"}"#),
                       "mixed value types: the answer is read as [String: Any]")
        XCTAssertThrowsError(try AccountService.loginSucceeded("<html></html>"))
    }

    func testCreatedCategoryNeedsANumericId() throws {
        XCTAssertEqual(try AccountService.createdCategory(#"{"success":true,"id":42}"#, name: "Мультики"),
                       Bookmark(id: 42, name: "Мультики"))
        XCTAssertNil(try AccountService.createdCategory(#"{"success":false,"message":"Ошибка"}"#, name: "x"))
        XCTAssertNil(try AccountService.createdCategory(#"{"success":true,"id":"42"}"#, name: "x"),
                     "`as? Int` as in the binary: a string id gives nil")
    }

    func testPersonSlugDropsPrefixAndEverySlash() {
        XCTAssertEqual(PeopleRepository.slug("person/4176-vudi-harrelson/"), "4176-vudi-harrelson")
        XCTAssertEqual(PeopleRepository.slug("4176-vudi-harrelson"), "4176-vudi-harrelson")
        XCTAssertEqual(PeopleRepository.slug("/person/4176-vudi-harrelson/"), "4176-vudi-harrelson")
    }

    // MARK: - Premium badge on login and logout (the original only read it from the next listing page)

    func testLoginReadsPremiumFromTheStartPageAtOnce() async throws {
        keepPremiumDefault("")
        let network = SpyAccountNetwork()
        network.answer = { request in
            request.url?.absoluteString.hasSuffix("/ajax/login/") == true
                ? #"{"success":true}"#
                : #"<div class="b-tophead-premuser"><a href="/payments/">Premium <b>осталось 12 дней</b></a></div>"#
        }
        let loggedIn = try await AccountService().login(username: "neo", password: "pw", network: network)
        XCTAssertTrue(loggedIn)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "hasPremium"), "осталось 12 дней")
        try check(network.sent.last, "GET", "https://\(network.settingStore)", version: network.remoteVersion)
    }

    func testFailedLoginDoesNotLoadTheStartPage() async throws {
        keepPremiumDefault("")
        let network = SpyAccountNetwork()
        network.answer = { _ in #"{"success":false}"# }
        let loggedIn = try await AccountService().login(username: "neo", password: "wrong", network: network)
        XCTAssertFalse(loggedIn)
        XCTAssertEqual(network.sent.count, 1)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "hasPremium"), "")
    }

    func testLogoutForgetsPremium() async throws {
        keepPremiumDefault("осталось 12 дней")
        let network = SpyAccountNetwork()
        try await AccountService().logout(network: network)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "hasPremium"), "")
        try check(network.sent.last, "GET", "https://\(network.settingStore)/logout", version: network.remoteVersion)
    }

    // MARK: - Helpers

    /// Sets the host app's "hasPremium" for this test and restores the real value afterwards.
    private func keepPremiumDefault(_ value: String) {
        let saved = UserDefaults.standard.string(forKey: "hasPremium")
        addTeardownBlock { UserDefaults.standard.set(saved, forKey: "hasPremium") }
        UserDefaults.standard.set(value, forKey: "hasPremium")
    }

    private static let formType = "application/x-www-form-urlencoded; charset=UTF-8"
    private var formType: String { Self.formType }
    /// Added by URLEncodedFormParameterEncoder when the request has no Content-Type of its own.
    private let alamofireFormType = "application/x-www-form-urlencoded; charset=utf-8"

    /// `contentType: nil` means the request must not carry a Content-Type header.
    private func check(_ request: URLRequest?, _ method: String, _ url: String, version: String,
                       contentType: String? = CatalogAccountTests.formType, body: String? = nil,
                       file: StaticString = #filePath, line: UInt = #line) throws {
        let request = try XCTUnwrap(request, file: file, line: line)
        XCTAssertEqual(request.httpMethod, method, file: file, line: line)
        XCTAssertEqual(request.url?.absoluteString, url, file: file, line: line)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Hdrezka-Ios-App"), "1", file: file, line: line)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Hdrezka-Ios-App-Version"), version, file: file, line: line)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), contentType, file: file, line: line)
        XCTAssertEqual(request.httpBody.map { String(decoding: $0, as: UTF8.self) }, body, file: file, line: line)
    }
}

// The spies pin mirror and version: the host app can write the real AppStorage keys mid-test
// (HomeView stores HeaderUpdater.updateHeader() whenever the scene turns active, 0x1000ecb5c).
private final class SpyAccountNetwork: AccountNetwork {
    var sent: [URLRequest] = []
    var answer: (URLRequest) -> String = { _ in "" }
    override var settingStore: String { get { "mirror.test" } set {} }
    override var remoteVersion: String { get { "9.9.9-test" } set {} }
    override func send(_ request: URLRequest) async throws -> String { sent.append(request); return answer(request) }
}

private final class SpyCollectionsNetwork: CollectionsNetwork {
    var sent: [URLRequest] = []
    override var settingStore: String { get { "mirror.test" } set {} }
    override var remoteVersion: String { get { "9.9.9-test" } set {} }
    override func send(_ request: URLRequest) async throws -> String { sent.append(request); return "" }
}

private final class SpyPeopleNetwork: PeopleNetwork {
    var sent: [URLRequest] = []
    override var settingStore: String { get { "mirror.test" } set {} }
    override var remoteVersion: String { get { "9.9.9-test" } set {} }
    override func send(_ request: URLRequest) async throws -> String { sent.append(request); return "" }
}
