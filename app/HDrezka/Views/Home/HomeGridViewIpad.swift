import SwiftUI

/// iPad start page (0x100031ae8…0x1000329a0); unlike HomeView it never refreshes the app-version header.
struct HomeGridViewIpad: View {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("startupPageVariation") var startupPageVariation: StartupPageVariation = .watching
    @EnvironmentObject var network: Network
    @Binding var isPresented: Bool
    @Binding var id: String
    // Default as at the construction site in HomeViewIpad (0x1000579ac).
    @State var page: Int = 0
    @State var refreshCount = 0

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack {
                    ContinueWatchingRow(refreshToken: refreshCount)
                    HomeView.listingMenu($startupPageVariation)
                        .padding(.horizontal)
                        .padding(.top, DesignTokens.space8)
                    TitleGridComponentIpad(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], page: $page)
                        .onLoad { page = 1 }
                }
            }
            .navigationTitle("Home")
            .onChange(of: startupPageVariation) { _, variation in
                network.movies.removeAll()
                HomeView.refresh(network, page: $page, variation: variation)
            }
            // improvement: pull to refresh, as on the phone (HomeView.refresh).
            .refreshable {
                refreshCount += 1
                HomeView.refresh(network, page: $page, variation: startupPageVariation)
                await network.nextPageArrival()
            }
            .refreshFailureNotice(network)
            .onChange(of: page) {
                Task {
                    try await network.fetchMovies(page: page, filter: HomeView.filter(for: startupPageVariation))
                }
            }
            .navigationDestination(isPresented: $isPresented) {
                DetailsView(id: id)
            }
        }
    }
}
