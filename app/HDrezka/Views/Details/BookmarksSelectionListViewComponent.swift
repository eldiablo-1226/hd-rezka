import SwiftUI

struct BookmarksSelectionListViewComponent: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @Binding var bookmarks: [Bookmark: Bool]
    @State private var saveFailed = false

    // Bookmark categories of the open movie; a tap sends add_post for SharedFilmId.id and flips the mark (0x1000686e8).
    // improvement: a system list with a trailing checkmark (1.6.0 drew its own grey rounded rows), and a failed request
    // takes the mark back and says so instead of showing a change the site never made.
    var body: some View {
        NavigationStack {
            Group {
                if !isLoggedIn {
                    notice("key_login+to+add+bookmarks", systemImage: "person.crop.circle")
                } else if bookmarks.isEmpty {
                    notice("key_no+cat", systemImage: "bookmark")
                } else {
                    List {
                        Section {
                            // improvement: categories in the site's order (their ids); a Dictionary's order changed between openings.
                            ForEach(bookmarks.sorted { $0.key.id < $1.key.id }, id: \.key) { bookmark in
                                row(bookmark.key, isOn: bookmark.value)
                            }
                        } footer: {
                            if saveFailed {
                                Text("key_bookmark_failed")
                            }
                        }
                    }
                }
            }
            .navigationTitle("key_bookmarks")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ category: Bookmark, isOn: Bool) -> some View {
        Button {
            toggle(category)
        } label: {
            HStack {
                Text(category.name)
                    .foregroundStyle(Color.primary)
                Spacer(minLength: DesignTokens.space8)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isOn ? 1 : 0)
                    // `.isSelected` says it; VoiceOver read the hidden mark too.
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// The mark flips at once; the site's add_post toggles the film in that category, so a failure flips it back.
    /// A failure is an error or an answer without `success: true`, which is what the site's own script waits for
    /// (script.673.js, action add_post); a session that isn't valid on this mirror gets a 200 with `success: false`.
    private func toggle(_ category: Bookmark) {
        saveFailed = false
        withAnimation(.default) { bookmarks[category]?.toggle() }
        Task { @MainActor in
            let answer = try? await AccountService().addToBookmarks(movieId: Self.postId(filmId: SharedFilmId.id),
                                                                    bookmarkUserCategory: category.id)
            if answer?.isSuccess() != true {
                withAnimation(.default) { bookmarks[category]?.toggle() }
                saveFailed = true
            }
        }
    }

    private func notice(_ text: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: DesignTokens.space8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// post_id sent to /ajax/favorites/: the last path component of the movie URL up to the first "." (0x1000698dc).
    static func postId(filmId: String) -> String {
        filmId.components(separatedBy: "/").last!.components(separatedBy: ".").first!
    }
}
