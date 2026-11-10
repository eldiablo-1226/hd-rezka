import SwiftUI

/// iPad grid of one collection, "watching" filter, first page only (no own NavigationStack).
struct CollectionsMovieListViewComponentIpad: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 160), spacing: 16)]
    @EnvironmentObject var collectionsParser: CollectionsParser
    var name: String
    var id: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns) {
                ForEach(collectionsParser.moviesInCollections) { movie in
                    NavigationLink(destination: DetailsView(id: movie.id)) {
                        TitleCardComponentIpad(model: movie)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(name)
        .padding(.horizontal)
        .onAppear {
            Task {
                try await collectionsParser.getWatchingNowMoviesInCollection(collectionId: id, page: 1)
            }
        }
    }
}
