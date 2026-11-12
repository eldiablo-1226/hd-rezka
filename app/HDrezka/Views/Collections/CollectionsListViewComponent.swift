import SwiftUI
import AlertKit

/// iPhone «Каталог» tab: the site's header menu, then its collections, two per row; the card of the last loaded
/// collection loads the next page.
struct CollectionsListViewComponent: View {
    // Top-aligned: a one-line name keeps its count right under it, and the covers of a row stay level.
    var columns: [GridItem] = [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)]
    @State var page: Int = 1
    @Binding var isPresented: Bool
    @Binding var id: String
    @EnvironmentObject var collectionsParser: CollectionsParser
    @State var loadFailure: PageLoadFailure? = nil
    /// improvement: bumped by pull to refresh; a page requested before it is dropped when it arrives.
    @State var generation = 0

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
                            ForEach(collectionsParser.collections) { collection in
                                NavigationLink(destination: CollectionsMovieListViewComponent(id: collection.id, name: collection.name)
                                    .environmentObject(CollectionsParser())) {
                                    CollectionsCardViewComponent(collection: collection)
                                        .onAppear {
                                            if collection == collectionsParser.collections.last {
                                                page += 1
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                            // improvement: shimmer cards until the first page arrives (1.6.0 showed an empty screen).
                            if collectionsParser.collections.isEmpty {
                                ForEach(0..<8, id: \.self) { _ in
                                    CollectionsCardViewComponent(collection: .placeholder)
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
        // Both reload the current page and append it; the parser skips collections it already has.
        .onAppear { Task { await load() } }
        .onChange(of: page) { Task { await load() } }
    }

    /// improvement: pull to refresh. Page 1 replaces the list when it brings collections; until then, and when it
    /// fails, the list stays (with a notice). Paging restarts from page 1.
    private func refresh() async {
        generation += 1
        let current = generation
        let replaced = await Self.firstPage(replacing: collectionsParser) != nil
        guard current == generation else { return }
        if replaced {
            loadFailure = nil
            // Reloads page 1 through onChange; harmless, the parser skips collections it already has.
            page = 1
        } else if collectionsParser.collections.isEmpty {
            await load()
        } else {
            AlertKitAPI.present(title: String(localized: "key_refresh_failed"), icon: .error, style: .iOS17AppleMusic, haptic: .error)
        }
    }

    /// Loads page 1 and swaps it in only when it parses to at least one collection; nil when nothing changed.
    @MainActor
    static func firstPage(replacing parser: CollectionsParser) async -> [Collection]? {
        guard let html = try? await CollectionsNetwork().getCollections(page: 1) else { return nil }
        let previous = parser.collections
        parser.collections = []
        if (try? parser.parseCollections(html)) == nil || parser.collections.isEmpty {
            parser.collections = previous
            return nil
        }
        return parser.collections
    }

    /// Appends `page`. improvement: with nothing loaded yet, an error or an answer without collections shows Retry
    /// (1.6.0 dropped the error and left the screen empty).
    private func load() async {
        var failure = PageLoadFailure.other
        let current = generation
        do {
            let html = try await CollectionsNetwork().getCollections(page: page)
            guard current == generation else { return }
            _ = try collectionsParser.parseCollections(html)
        } catch {
            guard current == generation else { return }
            failure = PageLoadFailure(error: error, statusCode: nil)
        }
        // Cleared as soon as a later load (onAppear, Retry) brings collections, so the error never covers a list.
        loadFailure = collectionsParser.collections.isEmpty ? failure : nil
    }
}
