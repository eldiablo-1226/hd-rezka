import SwiftUI

/// "Continue watching" list (body 0x100013ac0, load 0x1000140f0).
struct WatchLaterView: View {
    @EnvironmentObject var accountParser: AccountParser
    @State var watchingLaterMovies: [MovieWatchLater] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack {
                ForEachWithIndex(watchingLaterMovies, id: \.self) { index, movie in
                    WatchLaterCardComponent(movie: movie, moviePosition: index, movieList: $watchingLaterMovies)
                }
            }
            .padding(.top, 15)
        }
        .navigationTitle("key_watch_later")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            accountParser.watchingLaterMovies.removeAll()
            Task {
                watchingLaterMovies = try await accountParser.parseWatchingLaterMovies()
            }
        }
    }
}
