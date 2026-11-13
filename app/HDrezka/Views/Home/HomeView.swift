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
                // improvement: no stack spacing, and the header's 44 pt hit area grows above its text: the grid sat about
                // 35 pt under «Последние поступления», more than the header sat under the row above it.
                VStack(spacing: 0) {
                    ContinueWatchingRow(refreshToken: refreshCount)
                    Self.listingMenu($startupPageVariation)
                        .padding(.horizontal)
                        .padding(.top, DesignTokens.space8)
                    TitleGridComponent(page: $page)
                }
                .navigationTitle("Home")
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
        .onChange(of: startupPageVariation) { _, variation in
            network.movies.removeAll()
            Self.refresh(network, page: $page, variation: variation)
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                if phase == .active {
                    remoteVersion = try await HeaderUpdater.updateHeader()
                }
            }
        }
        .onChange(of: page) {
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
        refresh(network, page: page, filter: filter(for: variation))
    }

    /// The same for a «Каталог» listing, whose pages take no filter.
    @MainActor
    static func refresh(_ network: Network, page: Binding<Int>, filter: String) {
        network.beginRefresh()
        if page.wrappedValue == 1 {
            Task { try await network.fetchMovies(page: 1, filter: filter) }
        } else {
            page.wrappedValue = 1
        }
    }

    /// improvement: the listing's name heads the grid and is the menu that switches it; the screen is «Главная», with
    /// «Досмотреть» above the listing. 1.6.0 titled the screen after the listing (switched only in Settings), and
    /// «Последние поступления» didn't fit a large title. The chevron is the ember: the name is a control.
    static func listingMenu(_ selection: Binding<StartupPageVariation>) -> some View {
        Menu {
            Picker("key_startup_page", selection: selection) {
                ForEach(StartupPageVariation.allCases, id: \.self) { variation in
                    Text(LocalizedStringKey(variation.rawValue)).tag(variation)
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.space4) {
                Text(LocalizedStringKey(selection.wrappedValue.rawValue))
                    .font(.title3.bold())
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    // The menu says it's a menu; VoiceOver read the symbol's name too.
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)
            .contentShape(Rectangle())
        }
        .accessibilityHint(Text("key_listing_hint"))
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
        content.onChange(of: network.moviesRefreshFailed) { _, failed in
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
