import SwiftUI
import UIKit
import AlertKit

/// improvement: VoiceOver reads a change that appears away from its focus, such as a footer or a slow-site line.
/// Only while VoiceOver runs: nobody else hears it, and under XCTest the post stalled the main thread for minutes.
@MainActor
func announce(_ text: String.LocalizationValue) {
    guard UIAccessibility.isVoiceOverRunning else { return }
    UIAccessibility.post(notification: .announcement, argument: String(localized: text))
}

/// improvement: a failure toast that VoiceOver reads too; AlertKit's HUD isn't announced.
@MainActor
func presentFailure(_ text: String.LocalizationValue) {
    AlertKitAPI.present(title: String(localized: text), icon: .error, style: .iOS17AppleMusic, haptic: .error)
    announce(text)
}

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

    /// improvement: the one primary action in Liquid Glass on iOS 26 and later (the user's choice, 2026-11-11);
    /// `.borderedProminent` before it.
    func primaryButtonStyle() -> some View {
        modifier(ActionButtonStyle(isProminent: true))
    }

    /// Secondary actions and chips: clear Liquid Glass on iOS 26 and later, `.bordered` before it.
    func secondaryButtonStyle() -> some View {
        modifier(ActionButtonStyle(isProminent: false))
    }

    /// improvement: an opaque grouped ground under a list sheet. On iOS 26 a medium-detent sheet is glass, and the page's
    /// ember «Смотреть» button showed through it as an orange band behind the title.
    func opaqueSheetBackground() -> some View {
        presentationBackground(Color(uiColor: .systemGroupedBackground))
    }
}

/// Glass is a capsule, like the system's bars and segments around it. At accessibility sizes labels wrap to several
/// lines and a capsule turns into a tall pill whose ends cut into the text, so it becomes a rounded rectangle there.
/// This inner shape wins over the call site's, which stays for the bordered styles. Tint comes from the call site.
private struct ActionButtonStyle: ViewModifier {
    var isProminent: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let shape: ButtonBorderShape = typeSize.isAccessibilitySize
                ? .roundedRectangle(radius: DesignTokens.radiusButton) : .capsule
            if isProminent {
                content.buttonStyle(.glassProminent).buttonBorderShape(shape)
            } else {
                content.buttonStyle(.glass).buttonBorderShape(shape)
            }
        } else if isProminent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
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
