import XCTest
@testable import HDrezka

/// Search and collections views (area d1b): the requests the search views send inline.
final class ViewsD1BTests: XCTestCase {
    func testQuickSearchIsGETWithQueryAndAppHeadersOnly() throws {
        let request = try SearchView.Request.quick(mirror: "ijobs.app", query: "matrix", version: "2.2.5").asURLRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://ijobs.app/engine/ajax/search.php/?q=matrix")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Hdrezka-Ios-App"), "1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Hdrezka-Ios-App-Version"), "2.2.5")
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertNil(request.httpBody)
    }

    func testFullSearchAppendsQueryToTheSearchPageQuery() throws {
        let request = try SearchView.Request.full(mirror: "ijobs.app", query: "matrix", version: "2.2.5").asURLRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://ijobs.app/search/?do=search&subaction=search&q=matrix")
        XCTAssertEqual(request.allHTTPHeaderFields, ["X-Hdrezka-Ios-App": "1", "X-Hdrezka-Ios-App-Version": "2.2.5"])
    }

    func testSearchQueryIsFormEncoded() throws {
        let request = try SearchView.Request.full(mirror: "ijobs.app", query: "матрица 2&3", version: "").asURLRequest()
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.map(\.name), ["do", "subaction", "q"])
        XCTAssertEqual(items?.last?.value, "матрица 2&3")
        XCTAssertTrue(request.url!.absoluteString.hasSuffix("&q=%D0%BC%D0%B0%D1%82%D1%80%D0%B8%D1%86%D0%B0%202%263"))
    }
}
