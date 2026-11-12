import SwiftUI

/// "Continue watching" list (body 0x100013ac0, load 0x1000140f0).
struct WatchLaterView: View {
    @EnvironmentObject var accountParser: AccountParser
    @State var watchingLaterMovies: [MovieWatchLater] = []
    /// improvement: loading, failure and an empty list each look different (1.6.0 showed a blank screen for all three).
    @State var phase: Phase = .loading

    enum Phase: Equatable {
        case loading, loaded
        case failed(PageLoadFailure)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            // improvement: lazy, so only the visible cards fetch a missing poster.
            LazyVStack {
                ForEachWithIndex(watchingLaterMovies, id: \.self) { index, movie in
                    WatchLaterCardComponent(movie: movie, moviePosition: index, movieList: $watchingLaterMovies)
                }
            }
            .padding(.top, 15)
        }
        .overlay {
            if watchingLaterMovies.isEmpty {
                switch phase {
                case .loading:
                    LoadingOrb()
                case .failed(let failure):
                    PageLoadFailedView(failure: failure, retry: load)
                case .loaded:
                    ContentUnavailableView("key_nothing+here", systemImage: "clock")
                }
            }
        }
        .navigationTitle("key_watch_later")
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: load)
    }

    private func load() {
        accountParser.watchingLaterMovies.removeAll()
        phase = .loading
        Task {
            do {
                watchingLaterMovies = try await accountParser.parseWatchingLaterMovies()
                phase = .loaded
            } catch {
                phase = .failed(PageLoadFailure(error: error, statusCode: nil))
            }
        }
    }
}
