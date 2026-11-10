import SwiftUI

/// iPhone grid of one collection, "watching" filter, first page only.
struct CollectionsMovieListViewComponent: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 110), spacing: 10)]
    var id: String
    var name: String
    @EnvironmentObject var collectionsParser: CollectionsParser

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns) {
                    ForEach(collectionsParser.moviesInCollections) { movie in
                        NavigationLink(destination: DetailsView(id: movie.id)) {
                            TitleCardComponent(model: movie)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .onAppear {
                Task {
                    try await collectionsParser.getWatchingNowMoviesInCollection(collectionId: id, page: 1)
                }
            }
            .navigationTitle(name)
        }
    }
}
