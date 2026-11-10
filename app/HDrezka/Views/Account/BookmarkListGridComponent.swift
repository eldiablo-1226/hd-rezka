import SwiftUI

/// Grid of the loaded bookmark movies; the last card bumps the page (body 0x100010cdc).
struct BookmarkListGridComponent: View {
    @EnvironmentObject var network: Network
    @Binding var page: Int

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)]) {
                ForEach(network.bookmarks) { movie in
                    NavigationLink {
                        DetailsView(id: movie.id)
                    } label: {
                        TitleCardComponent(model: movie)
                    }
                    .buttonStyle(.plain)
                    .onAppear { loadMoreIfLast(movie) }
                }
            }
            .padding()
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)]) {
                ForEach(network.bookmarks) { movie in
                    NavigationLink {
                        DetailsView(id: movie.id)
                    } label: {
                        TitleCardComponentIpad(model: movie)
                    }
                    .buttonStyle(.plain)
                    .onAppear { loadMoreIfLast(movie) }
                }
            }
            .padding()
        }
    }

    private func loadMoreIfLast(_ movie: MovieSimple) {
        if movie == network.bookmarks.last {
            page += 1
        }
    }
}
