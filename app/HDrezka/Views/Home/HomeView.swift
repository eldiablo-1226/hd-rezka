import SwiftUI
import AlertKit

/// iPhone start page (0x1000ebff8). onLoad sets page 1, which triggers the first fetch through onChange(of: page).
struct HomeView: View {
    @AppStorage("remoteVersion") var remoteVersion: String = "0.0.0"
    @AppStorage("startupPageVariation") var startupPageVariation: StartupPageVariation = .watching
    @Binding var isPresented: Bool
    @Binding var id: String
    @EnvironmentObject var network: Network
    @Environment(\.scenePhase) var scenePhase
    // Defaults as at the construction site (0x100089f40): page 0, vpnPopup true.
    @State var page: Int = 0
    // Never read in 1.6.0: the binary has no VPN detection and no VPN popup.
    @State var connectedToVpn: Bool = false
    @State var vpnPopup: Bool = true
    @State var refreshCount = 0

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack {
                    ContinueWatchingRow(refreshToken: refreshCount)
                    TitleGridComponent(page: $page)
                }
                .navigationTitle(LocalizedStringKey(startupPageVariation.rawValue))
                // improvement: the listing is switched right here (1.6.0: only in Settings → Behaviour). A toolbar menu,
                // not toolbarTitleMenu: with a large title that menu has no visible affordance.
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Self.listingMenu($startupPageVariation) }
                }
            }
            // improvement: pull to refresh; the spinner stays until page 1 arrives and replaces the list.
            .refreshable {
                refreshCount += 1
                Self.refresh(network, page: $page, variation: startupPageVariation)
                await network.nextPageArrival()
            }
            .navigationDestination(isPresented: $isPresented) {
                DetailsView(id: id)
            }
        }
        .refreshFailureNotice(network)
        .preferredColorScheme(nil)
        .onLoad { page = 1 }
        .onChange(of: startupPageVariation) { variation in
            network.movies.removeAll()
            Self.refresh(network, page: $page, variation: variation)
        }
        .onChange(of: scenePhase) { phase in
            Task {
                if phase == .active {
                    remoteVersion = try await HeaderUpdater.updateHeader()
                }
            }
        }
        .onChange(of: page) { _ in
            Task {
                try await network.fetchMovies(page: page, filter: Self.filter(for: startupPageVariation))
            }
        }
    }

    /// Pull to refresh on phone and iPad: the listing again from page 1, which replaces the list when it arrives (the list
    /// stays on screen meanwhile and if the refresh fails). Setting `page` fetches through the views' onChange, page 1 is
    /// fetched here. Resetting `page` matters: the grid's paging cell asks for `page + 1` next.
    @MainActor
    static func refresh(_ network: Network, page: Binding<Int>, variation: StartupPageVariation) {
        network.beginRefresh()
        if page.wrappedValue == 1 {
            Task { try await network.fetchMovies(page: 1, filter: filter(for: variation)) }
        } else {
            page.wrappedValue = 1
        }
    }

    /// The start page listings, as a toolbar menu on phone and iPad.
    static func listingMenu(_ selection: Binding<StartupPageVariation>) -> some View {
        Menu {
            Picker("key_startup_page", selection: selection) {
                ForEach(StartupPageVariation.allCases, id: \.self) { variation in
                    Text(LocalizedStringKey(variation.rawValue)).tag(variation)
                }
            }
        } label: {
            Label("key_startup_page", systemImage: "line.3.horizontal.decrease")
        }
    }

    /// Listing filter of the start page: `String(describing:)` gives the case name ("watching", "last", "popular", "soon").
    static func filter(for variation: StartupPageVariation) -> String {
        String(describing: variation)
    }
}

/// improvement: a refresh that failed while the list stayed on screen gets a short notice instead of replacing the list.
private struct RefreshFailureNotice: ViewModifier {
    @ObservedObject var network: Network

    func body(content: Content) -> some View {
        content.onChange(of: network.moviesRefreshFailed) { failed in
            guard failed else { return }
            network.moviesRefreshFailed = false
            AlertKitAPI.present(title: String(localized: "key_refresh_failed"), icon: .error, style: .iOS17AppleMusic, haptic: .error)
        }
    }
}

extension View {
    func refreshFailureNotice(_ network: Network) -> some View {
        modifier(RefreshFailureNotice(network: network))
    }
}
