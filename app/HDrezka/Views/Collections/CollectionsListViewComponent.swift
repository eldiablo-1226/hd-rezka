import SwiftUI

/// iPhone list of collections, two per row; the card of the last loaded collection loads the next page.
struct CollectionsListViewComponent: View {
    var columns: [GridItem] = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    @State var page: Int = 1
    @Binding var isPresented: Bool
    @Binding var id: String
    @EnvironmentObject var collectionsParser: CollectionsParser

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
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
                }
                .navigationTitle("key_collections")
            }
            .padding(.horizontal, 16)
            .navigationDestination(isPresented: $isPresented) {
                DetailsView(id: id)
            }
        }
        // Both reload the current page and append it, so reappearing appends that page again (as in the original).
        .onAppear {
            Task {
                try await collectionsParser.parseCollections(CollectionsNetwork().getCollections(page: page))
            }
        }
        .onChange(of: page) { _ in
            Task {
                try await collectionsParser.parseCollections(CollectionsNetwork().getCollections(page: page))
            }
        }
    }
}
