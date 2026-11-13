import SwiftUI
import Alamofire
import SwiftSoup
import ThinkingOrbsKit

/// improvement: why a page did not load, so the error says what happened and offers the fix that can work.
enum PageLoadFailure: Equatable {
    case offline
    /// DNS, connection, TLS, timeout or 5xx: a dead or blocked mirror.
    case unreachable
    /// 403: the mirror opens film pages only after login. Not gated on the "isLoggedIn" flag: the session cookie
    /// belongs to one mirror, so after a mirror switch a logged-in user is a guest there.
    case needsLogin
    /// The site answered, but the parser could not read the page. Neither login nor another mirror fixes that, and
    /// after a mirror switch a logged-in user is a guest there (403 on film pages).
    case unparsable
    /// The site's own 404 page on a «Каталог» listing (an empty «Лучшие» year): there is nothing to show, and every mirror
    /// serves the same catalogue. Set by `Network.listingFailure`; any other 404 is `.other`, a host that isn't a mirror.
    case notFound
    /// An answer that is not the expected page (a block page served with 200).
    case other

    init(error: Error?, statusCode: Int?) {
        let status = statusCode ?? (error as? AFError)?.responseCode
        let urlError = (error as? URLError) ?? ((error as? AFError)?.underlyingError as? URLError)
        switch urlError?.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut, .secureConnectionFailed,
             .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .badServerResponse:
            self = .unreachable
        default:
            if status == 403 {
                self = .needsLogin
            } else if let status, (500..<600).contains(status) {
                self = .unreachable
            } else if error is PageParseError || error is SwiftSoup.Exception {
                self = .unparsable
            } else {
                self = .other
            }
        }
    }

    /// Another mirror can help only when this one is down, blocked or serving something else.
    var suggestsMirrorChange: Bool { self == .unreachable || self == .other }

    fileprivate var title: LocalizedStringKey {
        switch self {
        case .offline: "key_offline_title"
        case .unreachable: "key_unreachable_title"
        case .needsLogin: "key_needs_login_title"
        case .unparsable: "key_unparsable_title"
        case .notFound: "key_nothing+here"
        case .other: "key_page+not+loaded"
        }
    }

    fileprivate var message: LocalizedStringKey {
        switch self {
        case .offline: "key_offline_text"
        case .unreachable: "key_unreachable_text"
        case .needsLogin: "key_needs_login_text"
        case .unparsable: "key_unparsable_text"
        case .notFound: "key_not_found_text"
        case .other: "key_page+not+loaded_text"
        }
    }

    fileprivate var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .unreachable: "network.slash"
        case .needsLogin: "person.crop.circle.badge.exclamationmark"
        case .unparsable: "doc.text.magnifyingglass"
        case .notFound: "film"
        case .other: "exclamationmark.triangle"
        }
    }
}

/// improvement: a Thinking orb (ThinkingOrbsKit) instead of the page spinner. The state names the wait: `.searching` for search,
/// `.connecting` for the watch sheet's links, `.working` for a page. Rows, buttons and grids keep the system spinner and
/// skeletons, because their waits are short and a flashing orb reads as a glitch.
struct LoadingOrb: View {
    var state: OrbState = .working

    var body: some View {
        ThinkingOrb(state: state, size: .px64)
            // The kit's labels are English («Searching…») in every language.
            .accessibilityLabel("key_loading")
    }
}

/// improvement: after 8 s of loading it names the mirror that is slow, so a stall doesn't look like a frozen app. With
/// `retry` (the movie page; critique r1) a glass «Повторить» comes with it, so the way out isn't only Back. A request
/// gives up after `siteTimeout` without data or `siteDeadline` in all, and PageLoadFailedView takes over.
struct SlowLoadNotice: View {
    var retry: (() -> Void)? = nil
    @AppStorage("mirror") private var mirror: String = DefaultSettings.mirror
    @State private var isSlow = false

    var body: some View {
        // A VStack, not a Group: an empty Group has no view for `.task` to run on.
        VStack(spacing: DesignTokens.space16) {
            if isSlow {
                Text("key_slow_site \(mirror)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                if let retry {
                    Button("key_retry", action: retry)
                        .secondaryButtonStyle()
                        .tint(.primary)
                        .controlSize(.large)
                        .transition(.opacity)
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { isSlow = true }
            announce("key_slow_site \(mirror)")
        }
    }
}

/// improvement: shown instead of 1.6.0's endless spinner or skeletons when a page fails to load
/// (movie pages on phone and iPad, the watch sheet, Home, Collections, search and the account lists).
struct PageLoadFailedView: View {
    var failure: PageLoadFailure = .other
    var retry: () -> Void
    @State private var isPresentingMirror = false
    @State private var mirrorChanged = false
    @State private var isPresentingLogin = false

    var body: some View {
        message
            // iOS 26 draws large bordered buttons as capsules; DESIGN.md keeps capsules for list chips.
            .buttonBorderShape(.roundedRectangle(radius: DesignTokens.radiusButton))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Retried once the sheet is gone: the retry replaces this view, and with it the sheet's owner.
            .sheet(isPresented: $isPresentingMirror, onDismiss: {
                if mirrorChanged {
                    mirrorChanged = false
                    retry()
                }
            }) {
                NavigationStack {
                    MirrorSettingsView(onSave: { mirrorChanged = true })
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("key_cancel") { isPresentingMirror = false }
                            }
                        }
                }
            }
            // A swipe-away also lands here; the retry then shows the same message again.
            .sheet(isPresented: $isPresentingLogin, onDismiss: retry) {
                NavigationStack {
                    LogInView(accountService: AccountService())
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .opaqueSheetBackground()
            }
    }

    private var message: some View {
        ContentUnavailableView {
            Label(failure.title, systemImage: failure.systemImage)
        } description: {
            Text(failure.message)
        } actions: {
            actions
        }
    }

    /// One prominent action, the fix most likely to work, with Retry beside it; under each other when they don't fit.
    /// improvement: side by side, so under Home's listing header both stay above the tab bar.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.space8) { actionButtons }
            VStack(spacing: DesignTokens.space8) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        // improvement: full-size controls; at the default size they measured under 44 pt.
        if failure == .needsLogin {
            fix("login") { isPresentingLogin = true }
        } else if failure.suggestsMirrorChange {
            // The fix the message names («Попробуйте другое»): a link under Retry, it ended under Home's tab bar.
            fix("key_change_mirror") { isPresentingMirror = true }
        }
        // Grey, as secondary buttons are. An empty answer is final, so it has no Retry; pull to refresh still asks again.
        if failure != .notFound {
            Button("key_retry", action: retry)
                .secondaryButtonStyle()
                .tint(.primary)
                .controlSize(.large)
        }
    }

    private func fix(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .primaryButtonStyle()
            // The fill, not the tint: white on the dark-mode tint is about 3:1.
            .tint(Color("AccentFill"))
            .controlSize(.large)
    }
}
