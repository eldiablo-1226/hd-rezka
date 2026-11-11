import SwiftUI
import XCTest
@testable import HDrezka

/// Non-UI logic of the movie page area (d2a): titles, the genre line, the header fade, the bookmark post id
/// and the wipe transition geometry. Values come from the binary procedures named in each test.
final class ViewsD2ATests: XCTestCase {
    private func detail(nameOriginal: String?, releaseDate: String?) -> MovieDetailed {
        MovieDetailed(id: "", nameRussian: "Голодные игры", nameOriginal: nameOriginal, poster: "", hPoster: "",
                      duration: "142", description: "", releaseDate: releaseDate, country: "США", ageRestriction: "16+",
                      imdbRating: nil, kpRating: nil, genres: [MovieGenre(id: "g", name: "Фантастика")], lists: nil,
                      collections: nil, schedule: nil, franchise: nil, producer: nil, actors: nil, ytTrailerLink: nil,
                      ytTrailerPreview: nil, availability: .AVAILABLE_ON_REZKA, comingSoon: false, voiceActing: nil,
                      singleVoiceActingName: nil, voiceActingRating: nil, seasons: nil, video: nil, bookmarks: [:],
                      commentsCount: 0)
    }

    // 0x1000438ac / 0x100046540: the original title only when the setting is on and the page has one.
    func testTitlePrefersOriginalOnlyWhenEnabledAndPresent() {
        let both = detail(nameOriginal: "The Hunger Games", releaseDate: nil)
        XCTAssertEqual(DetailsViewComponent.title(both, preferOriginal: true), "The Hunger Games")
        XCTAssertEqual(DetailsViewComponent.title(both, preferOriginal: false), "Голодные игры")
        XCTAssertEqual(DetailsViewComponent.title(detail(nameOriginal: nil, releaseDate: nil), preferOriginal: true), "Голодные игры")
    }

    // improvement (Details redesign): the header's facts line replaces 0x10004767c's uppercased genre line: the year out
    // of the release date, no "unknown" when there is no date.
    func testFactsLine() {
        XCTAssertEqual(detail(nameOriginal: nil, releaseDate: "21 марта 2012 года").factsLine, "Фантастика · 2012 · США")
        XCTAssertEqual(detail(nameOriginal: nil, releaseDate: nil).factsLine, "Фантастика · США")
        XCTAssertEqual(detail(nameOriginal: nil, releaseDate: "скоро").factsLine, "Фантастика · скоро · США")
        XCTAssertEqual(MovieDetailed.year(in: "19 сентября 2026 года"), "2026")
        XCTAssertNil(MovieDetailed.year(in: "скоро"))
    }

    // 0x1000698dc: SharedFilmId holds the page URL; post_id is its last path component up to the first ".".
    func testBookmarkPostId() {
        XCTAssertEqual(BookmarksSelectionListViewComponent.postId(filmId: "https://hdrezka.ag/films/fiction/205-golodnye-igry-2012.html"),
                       "205-golodnye-igry-2012")
        XCTAssertEqual(BookmarksSelectionListViewComponent.postId(filmId: "series/drama/1605-gavayi-5-0"), "1605-gavayi-5-0")
    }

    // 0x100050638: the larger of the two boxes containing the rotated size.
    func testBoundingSize() {
        let flat = CGSize(width: 100, height: 50).boundingSize(at: .zero)
        XCTAssertEqual(flat.width, 100, accuracy: 1e-9)
        XCTAssertEqual(flat.height, 50, accuracy: 1e-9)
        let diagonal = CGSize(width: 100, height: 50).boundingSize(at: .degrees(45))
        XCTAssertEqual(diagonal.width, 150 / 2.0.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(diagonal.height, 150 / 2.0.squareRoot(), accuracy: 1e-9)
    }

    // improvement: the "Minutes" caption already names the unit, so only an exact "<digits> мин." loses it;
    // anything else (nil here) is shown raw and the caption is hidden.
    func testDurationDropsOnlyAnExactMinutesUnit() {
        XCTAssertEqual(InfoTabView.durationNumber("172 мин."), "172")
        XCTAssertEqual(InfoTabView.durationNumber("172 мин"), "172")
        XCTAssertNil(InfoTabView.durationNumber("1 ч. 30 мин."))
        XCTAssertNil(InfoTabView.durationNumber("40-50 мин."))
        XCTAssertNil(InfoTabView.durationNumber("~45 мин."))
        XCTAssertNil(InfoTabView.durationNumber("45"), "a bare number has no unit to replace")
        XCTAssertNil(InfoTabView.durationNumber("nil"), "the parser's placeholder for a missing duration")
        XCTAssertNil(InfoTabView.durationNumber(""))
    }

    // improvement: the parser force-unwraps the page's main block and title, so other pages (403, errors) are rejected first.
    func testMoviePageCheck() throws {
        let film = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/details-film-hunger-games.html"), encoding: .utf8)
        XCTAssertTrue(DetailsViewComponent.isMoviePage(film))
        XCTAssertFalse(DetailsViewComponent.isMoviePage("<html><body><h1>403 Forbidden</h1></body></html>"))
        XCTAssertFalse(DetailsViewComponent.isMoviePage(""))
    }
}
