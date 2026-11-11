import SwiftUI

/// Bookmark categories: open, create, rename, delete and reorder (body 0x10009b218).
/// improvement: loading, a failure and an account without categories each look different (1.6.0 showed a blank list for
/// all three). A delete asks first, as the site does, and every change waits for the site's `success: true`
/// (script.673.js) before the list shows it; a failure says so. 1.6.0 deleted on a full swipe without asking, removed
/// rows by a stale index, ignored the answers and accepted empty names.
struct BookmarksView: View {
    @State var bookmarks: [Bookmark] = []
    @State private var phase: Phase = .loading
    /// Categories with a request in flight: their row shows a spinner and can't be tapped.
    @State private var pending: Set<Int> = []
    @State private var deleting: Bookmark? = nil
    @State private var renaming: Bookmark? = nil
    @State private var isCreating = false
    @State private var name = ""
    /// A new order is on its way to the site; another move would restore a stale order on failure.
    @State private var isReordering = false

    enum Phase: Equatable {
        case loading, loaded
        case failed(PageLoadFailure)
    }

    var body: some View {
        List {
            ForEach(bookmarks, id: \.id) { bookmark in
                NavigationLink {
                    BookmarkMovieListView(name: bookmark.name, id: bookmark.id)
                } label: {
                    HStack {
                        Text(bookmark.name)
                        if pending.contains(bookmark.id) {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(pending.contains(bookmark.id))
                .moveDisabled(isReordering)
                // Not a full swipe: deleting a category takes its bookmarks with it on the site. A plain red button,
                // not `role: .destructive`, which starts removing the row before the question is answered.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        deleting = bookmark
                    } label: {
                        Label("key_delete", systemImage: "trash")
                    }
                    .tint(.red)
                    Button {
                        name = bookmark.name
                        renaming = bookmark
                    } label: {
                        Label("key_rename", systemImage: "pencil")
                    }
                    // improvement: grey, not blue, so the accent stays the one hue (DESIGN.md).
                    .tint(.gray)
                }
            }
            .onMove(perform: move)
        }
        .overlay {
            if bookmarks.isEmpty {
                state
            }
        }
        .navigationTitle("key_bookmarks")
        .task { await load() }
        .refreshable { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // improvement: the bare symbol with a name; 1.6.0's plus.circle drew its own circle in the glass.
                Button {
                    name = ""
                    isCreating = true
                } label: {
                    Label("key_new_category", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .confirmationDialog(Text("key_category_delete_title \(deleting?.name ?? "")"),
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { bookmark in
            Button("key_delete", role: .destructive) { delete(bookmark) }
            Button("key_cancel", role: .cancel) {}
        } message: { _ in
            Text("key_category_delete_message")
        }
        .alert("key_new_category", isPresented: $isCreating) {
            TextField("key_category_name", text: $name)
            Button("key_cancel", role: .cancel) {}
            Button("key_create", action: create)
                .disabled(Self.validName(name) == nil)
        }
        .alert("key_category_rename_title",
               isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
               presenting: renaming) { bookmark in
            TextField("key_category_name", text: $name)
            Button("key_cancel", role: .cancel) {}
            Button("key_rename") { rename(bookmark) }
                .disabled(Self.validName(name) == nil || Self.validName(name) == bookmark.name)
        }
    }

    @ViewBuilder
    private var state: some View {
        switch phase {
        case .loading:
            VStack(spacing: DesignTokens.space8) {
                ProgressView()
                SlowLoadNotice()
            }
            .padding()
        case .failed(let failure):
            PageLoadFailedView(failure: failure) { Task { await load() } }
        case .loaded:
            if #available(iOS 17.0, *) {
                ContentUnavailableView {
                    Label("key_no_categories_title", systemImage: "bookmark")
                } description: {
                    Text("key_no_categories_text")
                } actions: {
                    createButton
                }
            } else {
                VStack(spacing: DesignTokens.space16) {
                    Label("key_no_categories_title", systemImage: "bookmark")
                        .font(.title3.bold())
                    Text("key_no_categories_text")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    createButton
                }
                .padding(DesignTokens.space16)
            }
        }
    }

    private var createButton: some View {
        Button("key_new_category") {
            name = ""
            isCreating = true
        }
        .secondaryButtonStyle()
        .tint(.primary)
        .controlSize(.large)
    }

    /// A reload keeps the list on screen; only the first load shows the spinner.
    private func load() async {
        if bookmarks.isEmpty { phase = .loading }
        do {
            bookmarks = try await AccountService().getBookmarks()
            phase = .loaded
        } catch {
            if bookmarks.isEmpty { phase = .failed(PageLoadFailure(error: error, statusCode: nil)) }
        }
    }

    private func create() {
        guard let newName = Self.validName(name) else { return }
        Task {
            if let bookmark = try? await AccountService().createBookmarksCategory(name: newName) {
                withAnimation(.default) { bookmarks.append(bookmark) }
                phase = .loaded
            } else {
                presentFailure("key_category_create_failed")
            }
        }
    }

    private func rename(_ bookmark: Bookmark) {
        guard let newName = Self.validName(name) else { return }
        pending.insert(bookmark.id)
        Task {
            let renamed = (try? await AccountService().changeBookmarksCategoryName(id: bookmark.id, newName: newName)) == true
            pending.remove(bookmark.id)
            if renamed, let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
                withAnimation(.default) { bookmarks[index].name = newName }
            } else if !renamed {
                presentFailure("key_category_rename_failed")
            }
        }
    }

    /// Removed by id once the site confirms, so a second swipe or a reordered list can't take another row.
    private func delete(_ bookmark: Bookmark) {
        pending.insert(bookmark.id)
        Task {
            let deleted = (try? await AccountService().deleteBookmarksCategory(id: bookmark.id))?.isSuccess() == true
            pending.remove(bookmark.id)
            if deleted {
                withAnimation(.default) { bookmarks.removeAll { $0.id == bookmark.id } }
            } else {
                presentFailure("key_category_delete_failed")
            }
        }
    }

    /// The new order goes to the site; a failure puts the old one back.
    private func move(from source: IndexSet, to destination: Int) {
        let previous = bookmarks
        bookmarks.move(fromOffsets: source, toOffset: destination)
        let order = bookmarks
        isReordering = true
        Task {
            if (try? await AccountService().reorderBookmarksCategories(order)) != true {
                withAnimation(.default) { bookmarks = previous }
                presentFailure("key_category_reorder_failed")
            }
            isReordering = false
        }
    }

    /// A category name without surrounding spaces, or nil when nothing is left (the site's form refuses an empty one).
    static func validName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
