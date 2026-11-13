import SwiftUI
import AlertKit

/// iPad «Каталог» tab: the site's header menu, then its collections; only the first page of them is loaded (no paging
/// in the original).
struct CollectionsListViewComponentIpad: View {
    // Top-aligned: a one-line name keeps its count right under it, and the covers of a row stay level.
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 160), spacing: 16, alignment: .top)]
    @Binding var isPresented: Bool
    @Binding var id: String
    @EnvironmentObject var collectionsParser: CollectionsParser
    @State var loadFailure: PageLoadFailure? = nil

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                // improvement: the site's menu stays usable when the collections fail; it needs no request.
                CatalogMenu()
                CollectionsHeader()
                Group {
                    // improvement: a failed first page offers Retry instead of endless skeletons.
                    if let loadFailure {
                        PageLoadFailedView(failure: loadFailure) {
                            self.loadFailure = nil
                            Task { await load() }
                        }
                    } else {
                        LazyVGrid(columns: columns) {
                            ForEach(collectionsParser.collections, id: \.name) { collection in
                                NavigationLink(destination: CollectionsMovieListViewComponentIpad(name: collection.name, id: collection.id)) {
                                    CollectionsCardViewComponentIpad(collection: collection)
                                }
                                .buttonStyle(.plain)
                            }
                            // improvement: shimmer cards until the first page arrives (1.6.0 showed an empty screen).
                            if collectionsParser.collections.isEmpty {
                                ForEach(0..<8, id: \.self) { _ in
                                    CollectionsCardViewComponentIpad(collection: .placeholder)
                                        .redacted(reason: .placeholder)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("key_catalog")
            }
            .padding(.horizontal, 16)
            // improvement: pull to refresh reloads the first page (also from the error state).
            .refreshable { await refresh() }
            .navigationDestination(isPresented: $isPresented) {
                DetailsView(id: id)
            }
        }
        .onAppear { Task { await load() } }
    }

    /// improvement: pull to refresh; page 1 replaces the list only when it brings collections (phone: refresh()).
    private func refresh() async {
        if await CollectionsListViewComponent.firstPage(replacing: collectionsParser) != nil {
            loadFailure = nil
        } else if collectionsParser.collections.isEmpty {
            await load()
        } else {
            AlertKitAPI.present(title: String(localized: "key_refresh_failed"), icon: .error, style: .iOS17AppleMusic, haptic: .error)
        }
    }

    /// The first page only, as in the original. improvement: an error or an answer without collections shows Retry.
    private func load() async {
        var failure = PageLoadFailure.other
        do {
            _ = try await collectionsParser.parseCollections(CollectionsNetwork().getCollections(page: 1))
        } catch {
            failure = PageLoadFailure(error: error, statusCode: nil)
        }
        // Cleared as soon as a later load (onAppear, Retry) brings collections, so the error never covers a list.
        loadFailure = collectionsParser.collections.isEmpty ? failure : nil
    }
}
