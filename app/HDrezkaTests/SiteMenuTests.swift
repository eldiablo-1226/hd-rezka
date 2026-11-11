import XCTest
import UIKit
import Alamofire
import SwiftSoup
@testable import HDrezka

/// improvement: the «Каталог» tab carries the site's header menu (Фильмы, Сериалы, Мультфильмы, Аниме ▾, Новинки,
/// Анонсы, Подборки). SiteMenu is a snapshot of it; these tests hold the snapshot to the saved page.
final class SiteMenuTests: XCTestCase {
    /// catalog-listing.html was saved on 2026-11-10: its year pickers start at 2027, «Лучшие новинки» is 2026.
    private let savedOn = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 11, day: 10).date!

    private func fixture(_ name: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)"), encoding: .utf8)
    }

    /// The menu as a browser shows it: comments are not elements, so the commented-out items (Передачи и шоу, four
    /// cartoon studios) are not selected.
    private func siteMenu() throws -> [Element] {
        try SwiftSoup.parse(fixture("catalog-listing.html")).select("#topnav-menu > li.b-topnav__item").array()
    }

    private func path(_ link: Element) throws -> String {
        String(try link.attr("href").dropFirst())
    }

    func testSectionsAreTheSiteDropdownsInItsOrder() throws {
        let items = try siteMenu().map { try path($0.select("a.b-topnav__item-link").first()!) }
        XCTAssertEqual(items, ["films/", "series/", "cartoons/", "animation/", "new/", "announce/", "collections/"])
        XCTAssertEqual(SiteMenu.sections.map(\.path) + [SiteMenu.new, SiteMenu.announce], Array(items.prefix(6)))
    }

    func testGenresAreTheSitesInItsOrder() throws {
        for (section, item) in zip(SiteMenu.sections, try siteMenu()) {
            let genres = try item.select("ul.left a").array().map { SiteLink(name: try $0.text(), path: try path($0)) }
            XCTAssertEqual(section.genres, genres, section.id)
        }
    }

    func testStudiosAreTheSitesCollections() throws {
        for (section, item) in zip(SiteMenu.sections, try siteMenu()) {
            let studios = try item.select("ul.right li").array().filter { !$0.hasClass("hot") }.map { try $0.select("a").first()! }
            XCTAssertEqual(section.studios.map(\.title), try studios.map { try $0.attr("title") }, section.id)
            XCTAssertEqual(section.studios.map(\.path), try studios.map(path), section.id)
            for studio in section.studios {
                XCTAssertTrue(studio.title?.hasSuffix(studio.name) == true, "\(studio.name) is the end of \(studio.title ?? "")")
            }
        }
    }

    func testBestLinksAreTheSitesHotLinkAndPickers() throws {
        for (section, item) in zip(SiteMenu.sections, try siteMenu()) {
            XCTAssertEqual(section.bestPath(genre: nil, year: SiteMenu.currentYear(now: savedOn)),
                           try path(item.select("ul.right li.hot a").first()!), section.id)
            let genreOptions = try item.select("select.select-category option").array().map { String(try $0.attr("value").dropFirst()) }
            XCTAssertEqual([section.bestPath(genre: nil, year: 0)] + section.genres.map { section.bestPath(genre: $0, year: 0) },
                           genreOptions, section.id)
            let yearOptions = try item.select("select.select-year option").array().map { Int(try $0.attr("value")) }
            XCTAssertEqual([0] + SiteMenu.years(now: savedOn), yearOptions, section.id)
        }
    }

    func testBestPathAddsTheGenreAndTheYear() {
        let films = SiteMenu.sections[0]
        let drama = films.genres.first { $0.name == "Драмы" }
        XCTAssertEqual(films.bestPath(genre: nil, year: 0), "films/best/")
        XCTAssertEqual(films.bestPath(genre: nil, year: 2026), "films/best/2026/")
        XCTAssertEqual(films.bestPath(genre: drama, year: 0), "films/best/drama/")
        XCTAssertEqual(films.bestPath(genre: drama, year: 2026), "films/best/drama/2026/")
    }

    /// The pickers follow the calendar instead of the saved page: next year first, 1896 last.
    func testYearsMoveWithTheCalendar() {
        let newYear = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2028, month: 1, day: 2).date!
        XCTAssertEqual(SiteMenu.currentYear(now: newYear), 2028)
        XCTAssertEqual(SiteMenu.years(now: newYear).prefix(2), [2029, 2028])
        XCTAssertEqual(SiteMenu.years(now: newYear).last, 1896)
    }

    // MARK: listings

    @MainActor
    func testSectionListingPagesThroughItsPath() {
        let network = Network(listingPath: "films/best/drama/2026/")
        XCTAssertEqual(network.moviesURL(page: 1, filter: ""), "https://\(network.settingStore)/films/best/drama/2026/")
        XCTAssertEqual(network.moviesURL(page: 3, filter: ""), "https://\(network.settingStore)/films/best/drama/2026/page/3/")
    }

    @MainActor
    func testStartPageStillPagesThroughTheFilter() {
        let network = Network()
        XCTAssertEqual(network.moviesURL(page: 2, filter: "popular"), "https://\(network.settingStore)/page/2/?filter=popular")
    }

    /// An empty «Лучшие» year answers 404 with the site's own page («Ничего не можем найти по данному запросу»). A 404
    /// without the site's menu comes from a host that isn't a mirror, so it stays a failure that offers another mirror.
    func testOnlyTheSitesOwn404IsNothingFound() throws {
        let sitePage = try fixture("catalog-listing.html")
        XCTAssertEqual(Network.listingFailure(html: sitePage, error: nil, statusCode: 404), .notFound)
        XCTAssertEqual(Network.listingFailure(html: "<html><body>404 Not Found</body></html>", error: nil, statusCode: 404), .other)
        XCTAssertEqual(Network.listingFailure(html: nil, error: nil, statusCode: 404), .other)
        XCTAssertEqual(Network.listingFailure(html: sitePage, error: nil, statusCode: 403), .needsLogin)
        let missing = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))
        XCTAssertEqual(PageLoadFailure(error: missing, statusCode: nil), .other, "film pages, search and account lists keep the mirror hint")
    }

    // MARK: resources

    func testSectionSymbolsExist() {
        for symbol in SiteMenu.sections.map(\.symbol) + ["flame", "calendar"] {
            XCTAssertNotNil(UIImage(systemName: symbol), symbol)
        }
    }

    func testCatalogStringsExistInEveryTable() throws {
        let keys = ["key_catalog", "key_collections", "key_new", "key_announce", "key_best_new", "key_genre", "key_any_genre",
                    "key_year", "key_all_time", "key_show", "key_studios", "key_genres", "key_nothing+here", "key_not_found_text"]
            + SiteMenu.sections.flatMap { [$0.titleKey, $0.allKey, $0.bestKey, $0.findBestKey] }
        for language in ["en", "ru", "uk"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), language)
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: "<missing>", table: nil), "<missing>", "\(language): \(key)")
            }
        }
    }
}
