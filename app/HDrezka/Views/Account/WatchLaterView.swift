import SwiftUI

/// "Continue watching" list (body 0x100013ac0, load 0x1000140f0).
/// improvement: a system inset-grouped list instead of 1.6.0's grey cards, each with its own «Продолжить». A row opens
/// the page on «Смотреть» at the episode it marks. Delete is a swipe or the context menu (1.6.0: a long press on the
/// card's background), and the row goes only once the site confirms (1.6.0 removed it at once and dropped the answer).
struct WatchLaterView: View {
    @EnvironmentObject var accountParser: AccountParser
    @State var watchingLaterMovies: [MovieWatchLater] = []
    /// improvement: loading, failure and an empty list each look different (1.6.0 showed a blank screen for all three).
    @State var phase: Phase = .loading
    /// Rows whose removal is on its way to the site (by `dataId`): a spinner, and no taps.
    @State private var pending: Set<String> = []
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false

    enum Phase: Equatable {
        case loading, loaded
        case failed(PageLoadFailure)
    }

    var body: some View {
        List {
            ForEach(watchingLaterMovies, id: \.id) { movie in
                NavigationLink {
                    DetailsView(id: movie.id, opensOnWatch: true)
                } label: {
                    WatchLaterCardComponent(movie: movie, isRemoving: pending.contains(movie.dataId))
                }
                .disabled(pending.contains(movie.dataId))
                // Not a full swipe, and not `role: .destructive`, which starts removing the row before the site answers.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        remove(movie)
                    } label: {
                        Label("key_delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        remove(movie)
                    } label: {
                        Label("key_delete", systemImage: "trash")
                    }
                }
            }
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

    /// Gone by id once the site confirms, so a reload or a second swipe can't take another row. Home's «Продолжить
    /// просмотр» shows the same list from the device, so the device copy follows.
    private func remove(_ movie: MovieWatchLater) {
        // The swipe and the menu still work on a row with a spinner: one request per row.
        guard pending.insert(movie.dataId).inserted else { return }
        Task {
            let removed = (try? await AccountService().removeWatchingItem(item: movie)) == true
            pending.remove(movie.dataId)
            if removed {
                withAnimation(.default) { watchingLaterMovies.removeAll { $0.dataId == movie.dataId } }
                // Not after a sign-out meanwhile: the list belongs to the account that is gone.
                if isLoggedIn { ContinueWatchingCache.save(watchingLaterMovies) }
            } else {
                presentFailure("key_watch_later_delete_failed")
            }
        }
    }
}
