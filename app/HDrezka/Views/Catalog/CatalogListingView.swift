import SwiftUI

/// improvement: a page of the site's catalogue (a genre, «Лучшие», Новинки, Анонсы, a studio's collection) as Home's
/// grid, with its skeletons, paging, Retry and pull to refresh: a Network of its own pages through the page's path.
struct CatalogListingView: View {
    let title: String
    /// What a «Лучшие» listing was narrowed to («Драмы · 2026»).
    var subtitle: String?
    @StateObject private var network: Network
    @State private var page = 0

    init(title: String, subtitle: String? = nil, path: String) {
        self.title = title
        self.subtitle = subtitle
        _network = StateObject(wrappedValue: Network(listingPath: path))
    }

    var body: some View {
        ScrollView {
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            if UIDevice.current.userInterfaceIdiom == .pad {
                TitleGridComponentIpad(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], page: $page)
            } else {
                TitleGridComponent(page: $page)
            }
        }
        .navigationTitle(title)
        .environmentObject(network)
        .refreshable {
            HomeView.refresh(network, page: $page, filter: "")
            await network.nextPageArrival()
        }
        .refreshFailureNotice(network)
        // As on Home: page 1 is fetched through onChange.
        .onLoad { page = 1 }
        .onChange(of: page) { _, page in
            Task { try await network.fetchMovies(page: page, filter: "") }
        }
    }
}
