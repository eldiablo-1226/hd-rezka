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

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                TitleGridComponentIpad(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], page: $page)
                    .onLoad { page = 1 }
            }
            .navigationTitle(LocalizedStringKey(startupPageVariation.rawValue))
            .onChange(of: page) { _ in
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
