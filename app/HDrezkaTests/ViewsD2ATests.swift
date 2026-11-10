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

    // 0x10004767c: "<genre> • <release date or unknown> • <country>", uppercased.
    func testGenreLine() {
        let genre = MovieGenre(id: "g", name: "Фантастика")
        XCTAssertEqual(DetailsViewComponent.genreLine(genre, detail(nameOriginal: nil, releaseDate: "2012")), "ФАНТАСТИКА • 2012 • США")
        XCTAssertEqual(DetailsViewComponent.genreLine(genre, detail(nameOriginal: nil, releaseDate: nil)), "ФАНТАСТИКА • UNKNOWN • США")
    }

    // 0x10004af10: the blur starts where the title block begins; the initial heights (1, 1) must not give NaN.
    func testHeaderFadeLocation() {
        XCTAssertEqual(DetailsViewComponent.headerFadeLocation(inner: 300, outer: 400), 0.25)
        XCTAssertEqual(DetailsViewComponent.headerFadeLocation(inner: 1, outer: 1), 0)
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
}
