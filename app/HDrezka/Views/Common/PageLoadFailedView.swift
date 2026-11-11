import SwiftUI
import Alamofire
import SwiftSoup

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
        case .other: "key_page+not+loaded"
        }
    }

    fileprivate var message: LocalizedStringKey {
        switch self {
        case .offline: "key_offline_text"
        case .unreachable: "key_unreachable_text"
        case .needsLogin: "key_needs_login_text"
        case .unparsable: "key_unparsable_text"
        case .other: "key_page+not+loaded_text"
        }
    }

    fileprivate var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .unreachable: "network.slash"
        case .needsLogin: "person.crop.circle.badge.exclamationmark"
        case .unparsable: "doc.text.magnifyingglass"
        case .other: "exclamationmark.triangle"
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
            }
    }

    @ViewBuilder
    private var message: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView {
                Label(failure.title, systemImage: failure.systemImage)
            } description: {
                Text(failure.message)
            } actions: {
                actions
            }
        } else {
            VStack(spacing: DesignTokens.space16) {
                Label(failure.title, systemImage: failure.systemImage)
                    .font(.title3.bold())
                Text(failure.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                actions
            }
            .padding(DesignTokens.space16)
        }
    }

    /// One prominent action: the fix most likely to work; Retry stays next to it.
    @ViewBuilder
    private var actions: some View {
        // improvement: full-size controls; at the default size they measured under 44 pt.
        if failure == .needsLogin {
            Button("login") { isPresentingLogin = true }
                .primaryButtonStyle()
                // The fill, not the tint: white on the dark-mode tint is about 3:1.
                .tint(Color("AccentFill"))
                .controlSize(.large)
        }
        // Grey, as secondary buttons are; the accent marks the one fix (login, or the mirror link).
        Button("key_retry", action: retry)
            .secondaryButtonStyle()
            .tint(.primary)
            .controlSize(.large)
        if failure.suggestsMirrorChange {
            Button("key_change_mirror") { isPresentingMirror = true }
                .controlSize(.large)
        }
    }
}
