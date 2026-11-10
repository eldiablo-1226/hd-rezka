import SwiftUI
import UIKit

/// Runs `action` on the first `onAppear` only (0x1000dfa10).
struct ViewDidLoadModifier: ViewModifier {
    @State private var didLoad = false
    private let action: (() -> Void)?

    init(perform action: (() -> Void)? = nil) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content.onAppear {
            if didLoad == false {
                didLoad = true
                action?()
            }
        }
    }
}

extension View {
    func onLoad(perform action: (() -> Void)? = nil) -> some View {
        modifier(ViewDidLoadModifier(perform: action))
    }
}

extension UINavigationController {
    /// Drops the pop-gesture delegate so the swipe back works with a hidden navigation bar,
    /// except on iOS 17.0–17.4 (0x1000e006c).
    override open func viewDidLoad() {
        super.viewDidLoad()
        if SystemVersion().os.majorVersion == 17 {
            if SystemVersion().os.minorVersion >= 5 {
                interactivePopGestureRecognizer?.delegate = nil
            }
        } else {
            interactivePopGestureRecognizer?.delegate = nil
        }
    }
}
