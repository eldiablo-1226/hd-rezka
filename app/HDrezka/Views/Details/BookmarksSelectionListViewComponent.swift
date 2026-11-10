import SwiftUI

struct BookmarksSelectionListViewComponent: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @Binding var bookmarks: [Bookmark: Bool]

    // Bookmark categories of the open movie; a tap sends add_post for SharedFilmId.id and flips the mark (0x1000686e8).
    var body: some View {
        NavigationStack {
            if isLoggedIn {
                if !bookmarks.isEmpty {
                    ScrollView(.vertical, showsIndicators: true) {
                        // shortcut: the specialized Collection.map at 0x100068334 is taken as identity (dictionary to array), check its inlined closure
                        ForEach(bookmarks.map { $0 }, id: \.key) { bookmark in
                            row(bookmark)
                                .padding(.bottom, 6)
                        }
                        .navigationTitle("key_bookmarks")
                        // shortcut: display mode argument not decoded (call at 0x1000692ec), read the value passed in x0 there
                        .navigationBarTitleDisplayMode(.inline)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding()
                    }
                } else {
                    VStack {
                        Image(systemName: "bookmark")
                            .font(.largeTitle)
                        HStack {
                            Text("key_no+cat")
                                .bold()
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Image(systemName: "person.crop.circle")
                        .font(.largeTitle)
                    HStack {
                        Text("key_login+to+add+bookmarks")
                            .bold()
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
        }
    }

    // closure #2 in closure #1 in closure #1 (0x100069404); the symbol swap is animated from iOS 17 (closure #3, 0x100069d1c)
    @ViewBuilder
    private func row(_ bookmark: (key: Bookmark, value: Bool)) -> some View {
        let button = Button {
            Task { @MainActor in
                try await AccountService().addToBookmarks(movieId: Self.postId(filmId: SharedFilmId.id),
                                                          bookmarkUserCategory: bookmark.key.id)
            }
            withAnimation(.default) {
                bookmarks[bookmark.key]?.toggle()
            }
        } label: {
            Label(bookmark.key.name, systemImage: bookmark.value ? "bookmark.fill" : "bookmark")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())

        if #available(iOS 17.0, *) {
            AnyView(button.contentTransition(.symbolEffect(.replace)))
        } else {
            button
        }
    }

    /// post_id sent to /ajax/favorites/: the last path component of the movie URL up to the first "." (0x1000698dc).
    static func postId(filmId: String) -> String {
        filmId.components(separatedBy: "/").last!.components(separatedBy: ".").first!
    }
}
