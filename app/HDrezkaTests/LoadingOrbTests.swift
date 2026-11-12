import XCTest
import SwiftUI
@testable import HDrezka

/// The loading orb (ThinkingOrbsKit) that took the page spinners' place.
@MainActor
final class LoadingOrbTests: XCTestCase {
    func testVoiceOverReadsTheAppsLoadingLabelNotTheKitsEnglishOne() throws {
        let wasOn = try setAccessibilityAutomation(true)
        defer { _ = try? setAccessibilityAutomation(wasOn) }
        let host = UIHostingController(rootView: LoadingOrb(state: .searching))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()

        let labels = accessibilityLabels(in: host.view)
        XCTAssertFalse(labels.isEmpty, "SwiftUI exposed no accessibility elements")
        // The kit labels every state in English («Searching…») whatever the app's language.
        XCTAssertEqual(labels, [NSLocalizedString("key_loading", comment: "")])
    }
}

/// Reading what VoiceOver would read from a hosted SwiftUI view (LoadingOrbTests, DetailsRedesignTests).
@MainActor
extension XCTestCase {
    func accessibilityLabels(in element: NSObject) -> [String] {
        accessibilityLeaves(in: element).map { $0.accessibilityLabel ?? "" }
    }

    /// The elements VoiceOver would visit, in its order.
    func accessibilityLeaves(in element: NSObject) -> [NSObject] {
        if element.isAccessibilityElement { return [element] }
        let children = (element.accessibilityElements as? [NSObject]) ?? (element as? UIView)?.subviews ?? []
        return children.flatMap { accessibilityLeaves(in: $0) }
    }

    /// SwiftUI builds its accessibility tree only for an assistive client; automation mode, which UI tests turn on, is one.
    /// Private libAccessibility calls, in the test bundle only. Returns the previous state.
    func setAccessibilityAutomation(_ on: Bool) throws -> Bool {
        let handle = try XCTUnwrap(dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW))
        let get = unsafeBitCast(try XCTUnwrap(dlsym(handle, "_AXSAutomationEnabled")),
                                to: (@convention(c) () -> Int32).self)
        let set = unsafeBitCast(try XCTUnwrap(dlsym(handle, "_AXSSetAutomationEnabled")),
                                to: (@convention(c) (Int32) -> Void).self)
        let was = get() != 0
        set(on ? 1 : 0)
        return was
    }
}
