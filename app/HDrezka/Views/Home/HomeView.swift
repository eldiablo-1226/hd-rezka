import SwiftUI

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

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack {
                    TitleGridComponent(page: $page)
                }
                .navigationTitle(LocalizedStringKey(startupPageVariation.rawValue))
            }
            .navigationDestination(isPresented: $isPresented) {
                DetailsView(id: id)
            }
        }
        .preferredColorScheme(nil)
        .onLoad { page = 1 }
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

    /// Listing filter of the start page: `String(describing:)` gives the case name ("watching", "last", "popular", "soon").
    static func filter(for variation: StartupPageVariation) -> String {
        String(describing: variation)
    }
}
