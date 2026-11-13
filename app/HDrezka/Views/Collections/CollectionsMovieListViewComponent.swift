import SwiftUI

/// iPhone grid of one collection, "watching" filter, first page only.
/// improvement: skeleton cards while it loads, then the films, an empty state or the failure with Retry (1.6.0 showed a
/// blank page until the answer and kept it on a failure).
struct CollectionsMovieListViewComponent: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var id: String
    var name: String
    /// improvement: owned here. The list built it in its body, so a redraw (its next page arriving) handed this page a
    /// new, empty parser, and the films vanished behind «Похоже, тут ничего нет».
    @StateObject private var collectionsParser = CollectionsParser()
    @State private var phase: CollectionLoadPhase = .loading

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if collectionsParser.moviesInCollections.isEmpty && phase == .loading {
                    SlowLoadNotice()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: TitleCardComponent.columnMinimum(typeSize, phone: 110)), spacing: 10)]) {
                    ForEach(collectionsParser.moviesInCollections) { movie in
                        NavigationLink(destination: DetailsView(id: movie.id, preview: movie)) {
                            TitleCardComponent(model: movie)
                        }
                        .buttonStyle(.plain)
                    }
                    if collectionsParser.moviesInCollections.isEmpty && phase == .loading {
                        ForEach(0..<12, id: \.self) { _ in
                            TitleCardComponent(model: .placeholder)
                                .redacted(reason: .placeholder)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .overlay {
                if collectionsParser.moviesInCollections.isEmpty {
                    CollectionLoadState(phase: phase) { Task { await load() } }
                }
            }
            .onLoad {
                Task { await load() }
            }
            .navigationTitle(name)
        }
    }

    private func load() async {
        if collectionsParser.moviesInCollections.isEmpty { phase = .loading }
        phase = await CollectionLoadPhase.load {
            try await collectionsParser.getWatchingNowMoviesInCollection(collectionId: id, page: 1)
        } isEmpty: { collectionsParser.moviesInCollections.isEmpty }
    }
}

/// Where a collection's grid is; only an empty grid shows the failure, a reload keeps the films on screen.
enum CollectionLoadPhase: Equatable {
    case loading, loaded
    case failed(PageLoadFailure)

    @MainActor
    static func load(_ request: () async throws -> [MovieSimple], isEmpty: () -> Bool) async -> CollectionLoadPhase {
        do {
            _ = try await request()
            return .loaded
        } catch {
            return isEmpty() ? .failed(PageLoadFailure(error: error, statusCode: nil)) : .loaded
        }
    }
}

/// The overlay of an empty collection grid: the failure with Retry, or «Похоже, тут ничего нет».
struct CollectionLoadState: View {
    var phase: CollectionLoadPhase
    var retry: () -> Void

    var body: some View {
        switch phase {
        case .loading:
            EmptyView()
        case .failed(let failure):
            PageLoadFailedView(failure: failure, retry: retry)
        case .loaded:
            ContentUnavailableView("key_nothing+here", systemImage: "film")
        }
    }
}
