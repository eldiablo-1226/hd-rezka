import SwiftUI

/// Movies of one bookmark category, paged by the grid (body 0x100061f50).
/// improvement: a skeleton while it loads, its own empty and failure states, and the pages stay when a film opened from
/// here closes. 1.6.0 cleared the grid on every disappearance and fetched only the current page on return, so the
/// earlier pages and the place in them were gone; a failure or an empty category left a blank screen.
struct BookmarkMovieListView: View {
    var name: String
    var id: Int
    /// Owned for the screen's life: a redraw of the category list doesn't swap in an empty one.
    @State private var service = AccountService()
    @State private var page: Int = 1
    @State private var phase: Phase = .loading
    /// False once a page brings nothing new, the end of the category; the last card stops asking for more.
    @State private var hasMore = true
    /// The last page asked for didn't load while films are on screen: a Retry row asks for it again.
    @State private var pageFailed = false

    enum Phase: Equatable {
        case loading, loaded
        case failed(PageLoadFailure)
    }

    private var isEmpty: Bool { service.network.bookmarks.isEmpty }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack {
                if phase == .loading && isEmpty {
                    SlowLoadNotice()
                }
                BookmarkListGridComponent(page: $page, showsPlaceholders: phase == .loading && isEmpty,
                                          canLoadMore: hasMore && phase == .loaded && !pageFailed)
                    .environmentObject(service.network)
                if pageFailed {
                    Button("key_retry") {
                        pageFailed = false
                        Task { await fetch(page: page) }
                    }
                    .secondaryButtonStyle()
                    .tint(.primary)
                    .padding(.bottom)
                }
                // The next page.
                if phase == .loading && !isEmpty {
                    ProgressView()
                        .padding(.bottom)
                }
            }
            .navigationTitle(name)
        }
        .overlay {
            if isEmpty {
                state
            }
        }
        .preferredColorScheme(nil)
        .onLoad { Task { await fetch(page: 1) } }
        .onChange(of: page) { _, page in
            Task { await fetch(page: page) }
        }
        .preferredColorScheme(nil)  // second nil writer, as in the binary (outermost layer of 0x10043bfa0)
    }

    @ViewBuilder
    private var state: some View {
        switch phase {
        case .loading:
            EmptyView()
        case .failed(let failure):
            PageLoadFailedView(failure: failure) { Task { await fetch(page: 1) } }
        case .loaded:
            ContentUnavailableView("key_category_empty_title", systemImage: "bookmark",
                                   description: Text("key_category_empty_text"))
        }
    }

    /// Appends the page to the grid. A later page that fails keeps the list; only an empty one shows the failure.
    private func fetch(page: Int) async {
        phase = .loading
        let before = service.network.bookmarks.count
        do {
            let after = try await service.getBookmarksByCategory(id: id, page: page).count
            hasMore = after > before
            phase = .loaded
        } catch {
            pageFailed = !isEmpty
            phase = isEmpty ? .failed(PageLoadFailure(error: error, statusCode: nil)) : .loaded
        }
    }
}
