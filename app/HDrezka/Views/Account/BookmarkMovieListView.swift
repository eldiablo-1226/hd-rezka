import SwiftUI

/// Movies of one bookmark category, paged by the grid (body 0x100061f50).
struct BookmarkMovieListView: View {
    var accountService: AccountService
    var name: String
    var id: Int
    @State var page: Int = 1

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack {
                BookmarkListGridComponent(page: $page)
                    .environmentObject(accountService.network)
            }
            .navigationTitle(name)
        }
        .preferredColorScheme(nil)
        .onAppear {
            Task { try await accountService.getBookmarksByCategory(id: id, page: page) }
        }
        .onChange(of: page) { _ in
            Task { try await accountService.getBookmarksByCategory(id: id, page: page) }
        }
        .onDisappear {
            accountService.network.bookmarks.removeAll()
        }
        .preferredColorScheme(nil)  // second nil writer, as in the binary (outermost layer of 0x10043bfa0)
    }
}
