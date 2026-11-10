import SwiftUI
import AlertKit

/// Bookmark categories: open, create, rename, delete and reorder (body 0x10009b218).
struct BookmarksView: View {
    @State var bookmarks: [Bookmark] = []
    @State var selectedBookmark: Bookmark = Bookmark(id: 0, name: "")
    @State var isPresentedAdd: Bool = false
    @State var isPresentedRename: Bool = false
    @State var newIndex: Int = 0
    @State var name: String = ""
    @State var newName: String = ""

    var body: some View {
        List {
            ForEachWithIndex(bookmarks, id: \.self) { index, bookmark in
                NavigationLink {
                    BookmarkMovieListView(accountService: AccountService(), name: bookmark.name, id: bookmark.id)
                } label: {
                    Text(bookmark.name)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        Task {
                            _ = try await AccountService().deleteBookmarksCategory(id: bookmark.id)
                            _ = withAnimation(.default) { bookmarks.remove(at: index) }
                        }
                    } label: {
                        Image(systemName: "trash.fill")
                    }
                    .tint(.red)
                    Button {
                        selectedBookmark = bookmark
                        newIndex = index
                        isPresentedRename.toggle()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onDelete { _ in }  // enables edit-mode deletion UI only; deleting is the swipe action above
            .onMove { source, destination in
                Task {
                    bookmarks.move(fromOffsets: source, toOffset: destination)
                    try await AccountService().reorderBookmarksCategories(bookmarks)
                }
            }
        }
        .navigationTitle("key_bookmarks")
        .onAppear {
            Task {
                bookmarks = try await AccountService().getBookmarks()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentedAdd.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .alert("key_enter_name", isPresented: $isPresentedAdd) {
                    TextField("", text: $name)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    Button("key_cancel", role: .cancel) {
                        name.removeAll()
                    }
                    Button("key_create") {
                        if !name.isEmpty {
                            Task {
                                if let bookmark = try await AccountService().createBookmarksCategory(name: name) {
                                    withAnimation(.default) { bookmarks.append(bookmark) }
                                    name.removeAll()
                                } else {
                                    AlertKitAPI.present(title: String(localized: "key_error"), icon: .error,
                                                        style: .iOS17AppleMusic, haptic: .error)
                                }
                            }
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .alert("key_enter_name", isPresented: $isPresentedRename) {
            TextField("", text: $newName)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            Button("key_rename") {
                Task {
                    print(newName)
                    if try await AccountService().changeBookmarksCategoryName(id: selectedBookmark.id, newName: newName) {
                        withAnimation(.default) { bookmarks[newIndex].name = newName }
                        newName.removeAll()
                    } else {
                        AlertKitAPI.present(title: String(localized: "key_error"), icon: .error,
                                            style: .iOS17AppleMusic, haptic: .error)
                    }
                }
            }
            Button("key_cancel", role: .cancel) {
                newName.removeAll()
            }
        }
    }
}
