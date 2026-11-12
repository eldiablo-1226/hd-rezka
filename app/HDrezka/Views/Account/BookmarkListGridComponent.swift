import SwiftUI

/// Grid of the loaded bookmark movies; the last card bumps the page (body 0x100010cdc).
struct BookmarkListGridComponent: View {
    @EnvironmentObject var network: Network
    @Binding var page: Int
    /// improvement: skeleton cards while the first page loads (1.6.0 showed a blank page).
    var showsPlaceholders = false
    /// improvement: off at the end of the category and while a page loads, so the last card doesn't ask again and again.
    var canLoadMore = true

    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isPhone ? TitleCardComponent.columnMinimum(typeSize) : 160), spacing: isPhone ? 10 : 16)]) {
            ForEach(network.bookmarks) { movie in
                NavigationLink {
                    DetailsView(id: movie.id, preview: movie)
                } label: {
                    card(movie)
                }
                .buttonStyle(.plain)
                .onAppear { loadMoreIfLast(movie) }
            }
            if showsPlaceholders {
                ForEach(0..<12, id: \.self) { _ in
                    card(.placeholder)
                        .redacted(reason: .placeholder)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func card(_ movie: MovieSimple) -> some View {
        if isPhone {
            TitleCardComponent(model: movie)
        } else {
            TitleCardComponentIpad(model: movie)
        }
    }

    private func loadMoreIfLast(_ movie: MovieSimple) {
        if canLoadMore && movie == network.bookmarks.last {
            page += 1
        }
    }
}
