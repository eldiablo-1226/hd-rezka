import SwiftUI

struct BookmarksSelectionListViewComponent: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @Binding var bookmarks: [Bookmark: Bool]
    /// The page this sheet saves: its URL, and the title shown at the top of the list.
    /// improvement: 1.6.0 sent add_post for a global "open film" that only the page's spinner set, so after going back
    /// from another film the sheet saved that other film (0x1000686e8). The page passes its own id now.
    var filmId: String
    var title: String
    /// A sign-in from here: the page reloads, so the categories and their marks are the account's.
    var onSignedIn: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var pending: Set<Int> = []
    @State private var failure: SaveFailure? = nil
    @State private var isCreating = false
    @State private var newName = ""
    @State private var isPresentingLogin = false
    /// LogInView succeeded: the flag alone can't tell, it is already on when a session expired on this mirror.
    @State private var didSignIn = false

    /// Why the last change didn't reach the site.
    enum SaveFailure: Equatable {
        /// The site answered without `success: true`, most often a session that isn't valid on this mirror.
        case rejected
        /// No answer, or one that isn't the site's JSON.
        case network
        /// A new category wasn't created.
        case notCreated
    }

    // Bookmark categories of the open movie; a tap sends add_post for the page's film (0x1000686e8).
    // improvement: a system list with a trailing checkmark (1.6.0 drew its own grey rounded rows). The mark changes when
    // the site confirms; until then a spinner takes its place, so the sheet never shows a change the site didn't make.
    var body: some View {
        NavigationStack {
            Group {
                if isLoggedIn {
                    categories
                } else {
                    signInNotice
                }
            }
            .navigationTitle("key_bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
            .alert("key_new_category", isPresented: $isCreating) {
                TextField("key_category_name", text: $newName)
                Button("key_cancel", role: .cancel) {}
                Button("key_create", action: create)
                    .disabled(BookmarksView.validName(newName) == nil)
            }
            .sheet(isPresented: $isPresentingLogin, onDismiss: {
                if didSignIn {
                    didSignIn = false
                    onSignedIn()
                }
            }) {
                NavigationStack {
                    LogInView(accountService: AccountService(), onLoggedIn: { didSignIn = true })
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var categories: some View {
        List {
            Section {
                // improvement: categories in the site's order (their ids); a Dictionary's order changed between openings.
                ForEach(bookmarks.sorted { $0.key.id < $1.key.id }, id: \.key) { bookmark in
                    row(bookmark.key, isOn: bookmark.value)
                }
                // improvement: a category can be made right here, with the film going into it; 1.6.0 sent the user to
                // Profile and back.
                Button {
                    newName = ""
                    isCreating = true
                } label: {
                    Label("key_new_category", systemImage: "plus")
                }
            } header: {
                // Which film the marks belong to, so a sheet can't quietly save another one.
                Text(title)
                    .textCase(nil)
            } footer: {
                footer
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch failure {
        case .rejected?:
            VStack(alignment: .leading, spacing: DesignTokens.space8) {
                Text("key_bookmark_rejected")
                Button("login") { isPresentingLogin = true }
                    .font(.footnote.weight(.semibold))
            }
        case .network?:
            Text("key_bookmark_failed")
        case .notCreated?:
            Text("key_category_create_failed")
        case nil:
            if bookmarks.isEmpty {
                Text("key_no+cat")
            }
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
                if pending.contains(category.id) {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .opacity(isOn ? 1 : 0)
                        // `.isSelected` says it; VoiceOver read the hidden mark too.
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(pending.contains(category.id))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// The site's add_post toggles the film in that category; the mark follows the answer.
    private func toggle(_ category: Bookmark) {
        failure = nil
        pending.insert(category.id)
        Task { @MainActor in
            var answer: String?
            var error: Error?
            do {
                answer = try await AccountService().addToBookmarks(movieId: Self.postId(filmId: filmId),
                                                                   bookmarkUserCategory: category.id)
            } catch let thrown {
                error = thrown
            }
            pending.remove(category.id)
            if let reason = Self.saveFailure(answer: answer, error: error) {
                failure = reason
                announce(reason == .rejected ? "key_bookmark_rejected" : "key_bookmark_failed")
            } else {
                withAnimation(.default) { bookmarks[category]?.toggle() }
            }
        }
    }

    /// Creates the category, then saves the film in it.
    private func create() {
        guard let name = BookmarksView.validName(newName) else { return }
        failure = nil
        Task { @MainActor in
            do {
                guard let category = try await AccountService().createBookmarksCategory(name: name) else {
                    throw SiteRefusal()
                }
                withAnimation(.default) { bookmarks[category] = false }
                toggle(category)
            } catch is SiteRefusal {
                failure = .rejected
                announce("key_bookmark_rejected")
            } catch {
                failure = .notCreated
                announce("key_category_create_failed")
            }
        }
    }

    private var signInNotice: some View {
        ContentUnavailableView {
            Label("key_login+to+add+bookmarks", systemImage: "person.crop.circle")
        } actions: {
            signInButton
        }
    }

    // improvement: the notice leads to sign-in; 1.6.0's said "sign in" with nothing to tap.
    private var signInButton: some View {
        Button("login") { isPresentingLogin = true }
            .primaryButtonStyle()
            // The fill, not the tint: white on the dark-mode tint is about 3:1.
            .tint(Color("AccentFill"))
            .controlSize(.large)
    }

    /// Why a save failed, or nil when the site confirmed it: an error or an answer that isn't its JSON is the network;
    /// JSON without `success: true` is the site saying no (script.673.js, action add_post, waits for success == true).
    static func saveFailure(answer: String?, error: Error?) -> SaveFailure? {
        guard error == nil, let data = answer?.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let success = json["success"] as? Bool else { return .network }
        return success ? nil : .rejected
    }

    /// post_id sent to /ajax/favorites/: the last path component of the movie URL up to the first "." (0x1000698dc).
    static func postId(filmId: String) -> String {
        filmId.components(separatedBy: "/").last!.components(separatedBy: ".").first!
    }
}
