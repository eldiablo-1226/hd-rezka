import SwiftUI

/// iPad grid of one collection, "watching" filter, first page only (no own NavigationStack).
/// improvement: skeleton cards, an empty state and the failure with Retry, as on the phone.
struct CollectionsMovieListViewComponentIpad: View {
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 160), spacing: 16)]
    /// improvement: owned here, as on the phone; the list's redraw handed it a new, empty parser.
    @StateObject private var collectionsParser = CollectionsParser()
    var name: String
    var id: String
    @State private var phase: CollectionLoadPhase = .loading

    var body: some View {
        ScrollView(showsIndicators: false) {
            if collectionsParser.moviesInCollections.isEmpty && phase == .loading {
                SlowLoadNotice()
            }
            LazyVGrid(columns: columns) {
                ForEach(collectionsParser.moviesInCollections) { movie in
                    NavigationLink(destination: DetailsView(id: movie.id, preview: movie)) {
                        TitleCardComponentIpad(model: movie)
                    }
                    .buttonStyle(.plain)
                }
                if collectionsParser.moviesInCollections.isEmpty && phase == .loading {
                    ForEach(0..<12, id: \.self) { _ in
                        TitleCardComponentIpad(model: .placeholder)
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .navigationTitle(name)
        .padding(.horizontal)
        .overlay {
            if collectionsParser.moviesInCollections.isEmpty {
                CollectionLoadState(phase: phase) { Task { await load() } }
            }
        }
        .onLoad {
            Task { await load() }
        }
    }

    private func load() async {
        if collectionsParser.moviesInCollections.isEmpty { phase = .loading }
        phase = await CollectionLoadPhase.load {
            try await collectionsParser.getWatchingNowMoviesInCollection(collectionId: id, page: 1)
        } isEmpty: { collectionsParser.moviesInCollections.isEmpty }
    }
}
