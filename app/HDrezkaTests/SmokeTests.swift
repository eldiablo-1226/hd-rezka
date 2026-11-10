import XCTest
@testable import HDrezka

final class SmokeTests: XCTestCase {
    func testDefaultMirror() {
        XCTAssertEqual(DefaultSettings.mirror, "ijobs.app")
    }
}
